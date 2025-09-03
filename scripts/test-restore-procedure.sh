#!/bin/bash
# PlanetPlant Test Restore Procedure Script  
# Automated weekly test of backup restore functionality

set -euo pipefail

# Configuration
TEST_TYPE="${1:-weekly}"
TEST_DIR="/tmp/planetplant_restore_test"
LOG_FILE="/opt/planetplant/backup/logs/restore-test.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Function to log with timestamp
log() {
    local message="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $message" | tee -a "$LOG_FILE"
}

# Function to send notification
send_notification() {
    local status="$1"
    local message="$2"
    
    log "NOTIFICATION [$status]: $message"
    
    # Load notification configuration
    if [ -f "/opt/planetplant/backup/.env" ]; then
        source /opt/planetplant/backup/.env
    fi
    
    # Send Slack notification
    if [ -n "${SLACK_WEBHOOK:-}" ]; then
        local color="good"
        [ "$status" = "FAILED" ] && color="danger"
        [ "$status" = "WARNING" ] && color="warning"
        
        local slack_payload=$(cat << EOF
{
    "channel": "#planetplant-backups",
    "username": "planetplant-restore-test",
    "text": "🧪 Restore Test: $status",
    "attachments": [
        {
            "color": "$color",
            "fields": [
                {
                    "title": "Test Type",
                    "value": "$TEST_TYPE",
                    "short": true
                },
                {
                    "title": "Status",
                    "value": "$status",
                    "short": true
                },
                {
                    "title": "Message",
                    "value": "$message",
                    "short": false
                },
                {
                    "title": "Timestamp",
                    "value": "$(date)",
                    "short": true
                }
            ]
        }
    ]
}
EOF
)
        
        curl -s -X POST \
            -H "Content-type: application/json" \
            -d "$slack_payload" \
            "$SLACK_WEBHOOK" > /dev/null || true
    fi
}

# Function to test backup restore in isolated environment
test_restore_isolated() {
    log "🧪 Starting isolated restore test..."
    
    # Load environment
    if [ -f "/opt/planetplant/backup/.env" ]; then
        source /opt/planetplant/backup/.env
    fi
    
    export RESTIC_REPOSITORY="${RESTIC_REPOSITORY:-/opt/planetplant/backups/restic-repo}"
    export RESTIC_PASSWORD="${RESTIC_PASSWORD:-planetplant-backup-encryption-key}"
    
    # Clean test directory
    rm -rf "$TEST_DIR"
    mkdir -p "$TEST_DIR"
    trap "rm -rf $TEST_DIR" EXIT
    
    # Get latest snapshot
    local latest_snapshot
    latest_snapshot=$(restic snapshots --json | jq -r '.[-1].short_id' 2>/dev/null)
    
    if [ "$latest_snapshot" = "null" ] || [ -z "$latest_snapshot" ]; then
        send_notification "CRITICAL" "No snapshots available for restore test"
        return 1
    fi
    
    log "Testing restore of snapshot: $latest_snapshot"
    
    # Restore to test directory
    if restic restore "$latest_snapshot" --target "$TEST_DIR"; then
        log "✅ Snapshot restore successful"
    else
        send_notification "CRITICAL" "Snapshot restore failed during test"
        return 1
    fi
    
    # Verify critical files are restored
    local critical_files=(
        "$TEST_DIR/config/.env"
        "$TEST_DIR/config/docker-compose.yml"
        "$TEST_DIR/influxdb"
    )
    
    local missing_files=()
    for file in "${critical_files[@]}"; do
        if [ ! -e "$file" ]; then
            missing_files+=("$(basename "$file")")
        fi
    done
    
    if [ ${#missing_files[@]} -gt 0 ]; then
        send_notification "WARNING" "Critical files missing from restore test: ${missing_files[*]}"
        return 1
    fi
    
    log "✅ Critical files verified in restore"
    
    # Test configuration file validity
    if [ -f "$TEST_DIR/config/.env" ]; then
        # Basic .env file validation
        if grep -q "INFLUXDB_TOKEN" "$TEST_DIR/config/.env"; then
            log "✅ Configuration file validation passed"
        else
            send_notification "WARNING" "Configuration file appears invalid"
            return 1
        fi
    fi
    
    log "✅ Isolated restore test completed successfully"
    return 0
}

# Function to test database restore
test_database_restore() {
    if [ "$TEST_TYPE" != "monthly" ]; then
        log "ℹ️ Skipping database restore test (monthly only)"
        return 0
    fi
    
    log "🗄️ Testing database restore procedure..."
    
    # This is a non-destructive test using a temporary container
    local test_container="planetplant-influxdb-test"
    
    # Start temporary InfluxDB container
    docker run -d \
        --name "$test_container" \
        --network planetplant_planetplant-network \
        -p 8087:8086 \
        -v "$TEST_DIR/influxdb:/var/lib/influxdb2" \
        influxdb:2.7-alpine >/dev/null 2>&1 || {
        log "Failed to start test InfluxDB container"
        return 1
    }
    
    # Cleanup function
    cleanup_test_container() {
        docker stop "$test_container" >/dev/null 2>&1 || true
        docker rm "$test_container" >/dev/null 2>&1 || true
    }
    trap cleanup_test_container EXIT
    
    # Wait for container to start
    sleep 20
    
    # Test database connectivity
    if curl -f -s http://localhost:8087/ping >/dev/null 2>&1; then
        log "✅ Test database container started successfully"
    else
        send_notification "WARNING" "Test database container failed to start properly"
        return 1
    fi
    
    # Cleanup
    cleanup_test_container
    trap - EXIT  # Remove trap
    
    log "✅ Database restore test completed"
    return 0
}

# Function to generate test report
generate_test_report() {
    local status="$1"
    local duration="$2"
    
    local report_file="/opt/planetplant/backup/logs/restore-test-$(date +%Y%m%d).md"
    
    cat > "$report_file" << EOF
# Backup Restore Test Report

## Test Information
- **Date:** $(date)
- **Type:** $TEST_TYPE
- **Duration:** ${duration}s
- **Status:** $status
- **Snapshot Tested:** $(restic snapshots --json 2>/dev/null | jq -r '.[-1].short_id' || echo "Unknown")

## Test Results

### Repository Integrity
$(grep "Repository" "$LOG_FILE" | tail -5)

### Restore Capability
$(grep "restore" "$LOG_FILE" | tail -5)

### Critical Files Verification
$(grep "critical files" "$LOG_FILE" | tail -3)

## Summary
$([ "$status" = "SUCCESS" ] && echo "✅ All tests passed successfully" || echo "❌ Some tests failed - investigation required")

## Next Test Scheduled
- Daily: Tomorrow 05:00
- Weekly: Next $(date -d "next sunday" +%A) 05:00  
- Monthly: $(date -d "first day of next month" +"%B 1") 05:00

---
Generated by test-restore-procedure.sh
EOF

    log "📄 Test report generated: $report_file"
}

# Main test procedure
main() {
    local start_time=$(date +%s)
    
    log "🧪 Starting $TEST_TYPE restore procedure test..."
    
    # Create log directory
    mkdir -p "$(dirname "$LOG_FILE")"
    
    # Track test status
    local test_success=true
    local failed_tests=()
    
    # Execute test steps
    echo -e "${YELLOW}1/4 Testing repository integrity...${NC}"
    if ! /opt/planetplant/scripts/verify-backup-integrity.sh "$TEST_TYPE"; then
        test_success=false
        failed_tests+=("Repository integrity")
    fi
    
    echo -e "${YELLOW}2/4 Testing isolated restore...${NC}"
    if ! test_restore_isolated; then
        test_success=false
        failed_tests+=("Isolated restore")
    fi
    
    echo -e "${YELLOW}3/4 Testing database restore...${NC}"
    if ! test_database_restore; then
        test_success=false
        failed_tests+=("Database restore")
    fi
    
    echo -e "${YELLOW}4/4 Generating test report...${NC}"
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    if [ "$test_success" = true ]; then
        log "SUCCESS: Restore procedure test completed in ${duration}s"
        generate_test_report "SUCCESS" "$duration"
        
        echo ""
        echo -e "${GREEN}✅ RESTORE TEST PASSED${NC}"
        echo ""
        echo "📊 Test Summary:"
        echo "   Type: $TEST_TYPE"
        echo "   Duration: ${duration}s"
        echo "   Status: ✅ All tests passed"
        echo ""
        
        # Send notification for weekly/monthly tests only
        if [ "$TEST_TYPE" != "daily" ]; then
            send_notification "SUCCESS" "Restore procedure test passed ($TEST_TYPE) - RTO capability verified"
        fi
        
    else
        log "FAILED: Restore procedure test failed: ${failed_tests[*]}"
        generate_test_report "FAILED" "$duration"
        
        echo ""
        echo -e "${RED}❌ RESTORE TEST FAILED${NC}"
        echo ""
        echo "🚨 Failed tests:"
        for test in "${failed_tests[@]}"; do
            echo "   ❌ $test"
        done
        echo ""
        echo -e "${BLUE}🔧 Immediate Actions Required:${NC}"
        echo "   1. Review test logs: cat $LOG_FILE"
        echo "   2. Check backup system: docker ps | grep backup"
        echo "   3. Run backup integrity check: /opt/planetplant/scripts/verify-backup-integrity.sh"
        echo "   4. Create new backup: /opt/planetplant/scripts/backup-all.sh manual"
        echo "   5. Contact technical support"
        
        send_notification "CRITICAL" "Restore procedure test FAILED: ${failed_tests[*]} - RTO at risk!"
        exit 1
    fi
}

# Execute test
echo -e "${BLUE}🧪 PlanetPlant Restore Test${NC}"
echo "Test type: $TEST_TYPE"
echo "Started: $(date)"
echo ""

main
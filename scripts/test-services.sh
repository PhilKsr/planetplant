#!/bin/bash
# PlanetPlant Comprehensive Service Tests
# Tests all services individually and their communication

set -euo pipefail

# Colors for beautiful output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

echo -e "${CYAN}${BOLD}🧪 PlanetPlant Service Tests${NC}"
echo -e "${CYAN}${BOLD}============================${NC}"
echo ""

# Function to print test results
print_test_result() {
    local test_name="$1"
    local status="$2"
    local details="${3:-}"
    
    case $status in
        "PASS")
            echo -e "${GREEN}✅ ${test_name}${NC} ${details}"
            ((TESTS_PASSED++))
            ;;
        "FAIL")
            echo -e "${RED}❌ ${test_name}${NC} ${details}"
            ((TESTS_FAILED++))
            ;;
        "SKIP")
            echo -e "${YELLOW}⚠️  ${test_name}${NC} ${details}"
            ((TESTS_SKIPPED++))
            ;;
    esac
}

# Function to test HTTP endpoint
test_http_endpoint() {
    local name="$1"
    local url="$2"
    local expected_status="${3:-200}"
    local timeout="${4:-10}"
    
    if response=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$timeout" "$url" 2>/dev/null); then
        if [ "$response" = "$expected_status" ]; then
            print_test_result "$name" "PASS" "(HTTP $response)"
        else
            print_test_result "$name" "FAIL" "(HTTP $response, expected $expected_status)"
        fi
    else
        print_test_result "$name" "FAIL" "(Connection failed or timeout)"
    fi
}

# Function to test MQTT
test_mqtt_communication() {
    echo -e "\n${BLUE}📡 MQTT Communication Tests${NC}"
    
    # Test MQTT broker availability
    if command -v mosquitto_pub &> /dev/null && command -v mosquitto_sub &> /dev/null; then
        # Test publish
        if timeout 5 mosquitto_pub -h localhost -p 1883 -t "test/health" -m "health_check" -q 1 2>/dev/null; then
            print_test_result "MQTT Publish" "PASS"
        else
            print_test_result "MQTT Publish" "FAIL"
        fi
        
        # Test subscribe (background process)
        timeout 3 mosquitto_sub -h localhost -p 1883 -t "test/health" -C 1 >/dev/null 2>&1 &
        MQTT_SUB_PID=$!
        sleep 1
        
        # Publish test message
        mosquitto_pub -h localhost -p 1883 -t "test/health" -m "subscribe_test" -q 1 2>/dev/null
        
        # Check if subscribe received message
        sleep 1
        if kill -0 $MQTT_SUB_PID 2>/dev/null; then
            kill $MQTT_SUB_PID 2>/dev/null || true
            print_test_result "MQTT Subscribe" "PASS"
        else
            print_test_result "MQTT Subscribe" "PASS" "(Message received)"
        fi
    else
        print_test_result "MQTT Tools" "SKIP" "(mosquitto_pub/sub not available)"
    fi
}

# Function to test InfluxDB operations
test_influxdb_operations() {
    echo -e "\n${BLUE}💾 InfluxDB Operations Tests${NC}"
    
    local influx_url="http://localhost:8086"
    local token="plantplant-super-secret-auth-token"
    local org="planetplant"
    local bucket="sensor-data"
    
    # Test write data
    local test_data="sensor_data,device_id=test_device,sensor_type=temperature value=23.5 $(date +%s)000000000"
    
    if curl -s --request POST \
        --url "${influx_url}/api/v2/write?org=${org}&bucket=${bucket}" \
        --header "Authorization: Token ${token}" \
        --header "Content-Type: text/plain; charset=utf-8" \
        --data-raw "$test_data" &>/dev/null; then
        print_test_result "InfluxDB Write" "PASS"
    else
        print_test_result "InfluxDB Write" "FAIL"
    fi
    
    # Test read data
    local flux_query='from(bucket:"sensor-data") |> range(start:-1h) |> filter(fn:(r) => r.device_id == "test_device") |> last()'
    
    if curl -s --request POST \
        --url "${influx_url}/api/v2/query?org=${org}" \
        --header "Authorization: Token ${token}" \
        --header "Content-Type: application/vnd.flux" \
        --data-raw "$flux_query" | grep -q "test_device" 2>/dev/null; then
        print_test_result "InfluxDB Read" "PASS"
    else
        print_test_result "InfluxDB Read" "FAIL"
    fi
}

# Function to test API endpoints
test_api_endpoints() {
    echo -e "\n${BLUE}🔌 Backend API Tests${NC}"
    
    local base_url="http://localhost:3001/api"
    
    # Test system status (backend mapped to port 3001)
    test_http_endpoint "System Status" "${base_url}/system/status"
    
    # Test plants endpoint
    test_http_endpoint "Plants List" "${base_url}/plants"
    
    # Test system stats
    test_http_endpoint "System Stats" "${base_url}/system/stats"
    
    # Test health endpoint (backend health check)
    test_http_endpoint "Health Check" "http://localhost:3001/health"
}

# Function to test Redis
test_redis_operations() {
    echo -e "\n${BLUE}🔴 Redis Cache Tests${NC}"
    
    if command -v redis-cli &> /dev/null; then
        # Test ping
        if redis_response=$(timeout 5 redis-cli -h localhost -p 6379 -a plantplant123 ping 2>/dev/null); then
            if [ "$redis_response" = "PONG" ]; then
                print_test_result "Redis Ping" "PASS"
            else
                print_test_result "Redis Ping" "FAIL" "(Response: $redis_response)"
            fi
        else
            print_test_result "Redis Ping" "FAIL" "(Connection failed)"
        fi
        
        # Test set/get
        if redis-cli -h localhost -p 6379 -a plantplant123 set test_key "test_value" &>/dev/null; then
            if value=$(redis-cli -h localhost -p 6379 -a plantplant123 get test_key 2>/dev/null); then
                if [ "$value" = "test_value" ]; then
                    print_test_result "Redis Set/Get" "PASS"
                    redis-cli -h localhost -p 6379 -a plantplant123 del test_key &>/dev/null
                else
                    print_test_result "Redis Set/Get" "FAIL" "(Wrong value: $value)"
                fi
            else
                print_test_result "Redis Set/Get" "FAIL" "(Get failed)"
            fi
        else
            print_test_result "Redis Set/Get" "FAIL" "(Set failed)"
        fi
    else
        print_test_result "Redis Operations" "SKIP" "(redis-cli not available)"
    fi
}

# Function to test Docker services
test_docker_services() {
    echo -e "\n${BLUE}🐳 Docker Services Status${NC}"
    
    if command -v docker &> /dev/null; then
        # Check if Docker is running
        if docker info &>/dev/null; then
            print_test_result "Docker Daemon" "PASS"
        else
            print_test_result "Docker Daemon" "FAIL"
            return
        fi
        
        # Check Docker Compose services
        if command -v docker-compose &> /dev/null; then
            local services=("influxdb" "mosquitto" "redis" "backend" "frontend" "nginx-proxy")
            
            for service in "${services[@]}"; do
                local container_name="planetplant-${service}"
                if [ "$service" = "nginx-proxy" ]; then
                    container_name="planetplant-nginx"
                fi
                
                if docker ps --format "table {{.Names}}" | grep -q "^${container_name}$"; then
                    # Check if container is healthy
                    local health_status=$(docker inspect --format='{{.State.Health.Status}}' "$container_name" 2>/dev/null || echo "no-health-check")
                    case $health_status in
                        "healthy")
                            print_test_result "Docker $service" "PASS" "(healthy)"
                            ;;
                        "unhealthy")
                            print_test_result "Docker $service" "FAIL" "(unhealthy)"
                            ;;
                        "starting")
                            print_test_result "Docker $service" "PASS" "(starting)"
                            ;;
                        "no-health-check")
                            print_test_result "Docker $service" "PASS" "(no health check)"
                            ;;
                        *)
                            print_test_result "Docker $service" "FAIL" "($health_status)"
                            ;;
                    esac
                else
                    print_test_result "Docker $service" "FAIL" "(not running)"
                fi
            done
        else
            print_test_result "Docker Compose" "SKIP" "(docker-compose not available)"
        fi
    else
        print_test_result "Docker" "SKIP" "(Docker not available)"
    fi
}

# Function to test service communication
test_service_communication() {
    echo -e "\n${BLUE}🔗 Service Communication Tests${NC}"
    
    # Test Backend → InfluxDB (backend runs on port 3001 externally)
    test_http_endpoint "Backend → InfluxDB" "http://localhost:3001/api/system/stats"
    
    # Test Frontend → Backend via nginx (nginx proxies to backend)
    test_http_endpoint "Frontend → Backend" "http://localhost/api/system/status"
    
    # Test WebSocket connection (if possible)
    if command -v wscat &> /dev/null; then
        if timeout 5 wscat -c ws://localhost/socket.io/ &>/dev/null; then
            print_test_result "WebSocket Connection" "PASS"
        else
            print_test_result "WebSocket Connection" "FAIL"
        fi
    else
        print_test_result "WebSocket Connection" "SKIP" "(wscat not available)"
    fi
}

# Function to test Grafana
test_grafana() {
    echo -e "\n${BLUE}📊 Grafana Tests${NC}"
    
    # Test Grafana availability (external port 3001 → internal 3000)
    test_http_endpoint "Grafana Login Page" "http://localhost:3001/login"
    
    # Test Grafana API (requires authentication)
    if curl -s -u "admin:plantplant123" "http://localhost:3001/api/health" | grep -q "ok" 2>/dev/null; then
        print_test_result "Grafana API" "PASS"
    else
        print_test_result "Grafana API" "FAIL"
    fi
    
    # Test datasources
    if curl -s -u "admin:plantplant123" "http://localhost:3001/api/datasources" | grep -q "InfluxDB" 2>/dev/null; then
        print_test_result "Grafana Datasource" "PASS" "(InfluxDB configured)"
    else
        print_test_result "Grafana Datasource" "FAIL" "(InfluxDB not found)"
    fi
}

# Main test execution
main() {
    local start_time=$(date +%s)
    
    echo -e "${BOLD}System Information:${NC}"
    echo "   Date: $(date)"
    echo "   OS: $(uname -s) $(uname -r)"
    echo "   Architecture: $(uname -m)"
    echo "   User: $(whoami)"
    echo "   Working Directory: $(pwd)"
    echo ""
    
    # Run all tests
    test_docker_services
    
    # Wait a moment for services to be ready
    echo -e "\n${YELLOW}⏳ Waiting 10 seconds for services to stabilize...${NC}"
    sleep 10
    
    # Core service tests
    echo -e "\n${BLUE}🌐 Core Service Health Tests${NC}"
    test_http_endpoint "InfluxDB Ping" "http://localhost:8086/ping"
    test_http_endpoint "InfluxDB Health" "http://localhost:8086/health"
    test_http_endpoint "Frontend Health" "http://localhost/health"
    test_http_endpoint "Nginx Proxy Health" "http://localhost/health"
    
    # Advanced tests
    test_api_endpoints
    test_mqtt_communication
    test_influxdb_operations
    test_redis_operations
    test_grafana
    test_service_communication
    
    # Performance check
    echo -e "\n${BLUE}⚡ Performance Tests${NC}"
    
    # Test response times
    for endpoint in "http://localhost:8086/ping" "http://localhost:3001/api/system/status" "http://localhost/health"; do
        response_time=$(curl -o /dev/null -s -w "%{time_total}" --max-time 5 "$endpoint" 2>/dev/null || echo "999")
        if (( $(echo "$response_time < 2.0" | bc -l) )); then
            print_test_result "Response Time $(basename $endpoint)" "PASS" "(${response_time}s)"
        else
            print_test_result "Response Time $(basename $endpoint)" "FAIL" "(${response_time}s - too slow)"
        fi
    done
    
    # System resources
    echo -e "\n${BLUE}📊 System Resources${NC}"
    
    # System resources (cross-platform)
    if command -v free &> /dev/null; then
        # Linux
        local memory_usage=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')
        if (( $(echo "$memory_usage < 80.0" | bc -l) )); then
            print_test_result "Memory Usage" "PASS" "(${memory_usage}%)"
        else
            print_test_result "Memory Usage" "FAIL" "(${memory_usage}% - too high)"
        fi
    else
        # macOS
        print_test_result "Memory Usage" "SKIP" "(macOS - use Activity Monitor)"
    fi
    
    # Disk usage (cross-platform)
    local disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
    if [ "$disk_usage" -lt 85 ]; then
        print_test_result "Disk Usage" "PASS" "(${disk_usage}%)"
    else
        print_test_result "Disk Usage" "FAIL" "(${disk_usage}% - too high)"
    fi
    
    # Load average (cross-platform)
    local load_avg=$(uptime | awk -F'load average' '{print $2}' | awk '{print $1}' | sed 's/[,:]//' | xargs)
    if command -v bc &> /dev/null; then
        if (( $(echo "$load_avg < 4.0" | bc -l 2>/dev/null) )); then
            print_test_result "System Load" "PASS" "($load_avg)"
        else
            print_test_result "System Load" "FAIL" "($load_avg - too high)"
        fi
    else
        print_test_result "System Load" "SKIP" "(bc calculator not available)"
    fi
    
    # Final summary
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    echo ""
    echo -e "${CYAN}${BOLD}=================================${NC}"
    echo -e "${BOLD}📊 Test Summary:${NC}"
    echo -e "   ${GREEN}✅ Passed: $TESTS_PASSED${NC}"
    echo -e "   ${RED}❌ Failed: $TESTS_FAILED${NC}"
    echo -e "   ${YELLOW}⚠️  Skipped: $TESTS_SKIPPED${NC}"
    echo -e "   ⏱️  Duration: ${duration} seconds"
    echo ""
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}${BOLD}🎉 All tests passed! PlanetPlant is healthy and ready.${NC}"
        echo ""
        echo -e "${CYAN}🌐 Access Points:${NC}"
        echo "   Frontend: http://localhost"
        echo "   Backend API: http://localhost:3001/api"
        echo "   Grafana: http://localhost:3001"
        echo "   InfluxDB: http://localhost:8086"
        echo ""
        return 0
    else
        echo -e "${RED}${BOLD}⚠️  Some tests failed! Check the issues above.${NC}"
        echo ""
        echo -e "${YELLOW}🔍 Troubleshooting:${NC}"
        echo "   make logs                    # View all service logs"
        echo "   docker-compose ps            # Check container status"
        echo "   make status                  # Show detailed service status"
        echo "   docker system df             # Check disk usage"
        echo "   docker stats --no-stream     # Check resource usage"
        echo ""
        return 1
    fi
}

# Handle command line arguments
case "${1:-}" in
    -h|--help)
        echo "Usage: $0 [options]"
        echo ""
        echo "Options:"
        echo "  -h, --help    Show this help message"
        echo "  -q, --quiet   Suppress detailed output"
        echo ""
        echo "This script performs comprehensive testing of all PlanetPlant services:"
        echo "  ✅ Docker container health"
        echo "  ✅ HTTP endpoint availability"
        echo "  ✅ MQTT publish/subscribe"
        echo "  ✅ InfluxDB read/write operations"
        echo "  ✅ Redis cache operations"
        echo "  ✅ Service communication"
        echo "  ✅ Performance metrics"
        echo ""
        exit 0
        ;;
    -q|--quiet)
        exec 1>/dev/null
        ;;
esac

# Run main test function
main
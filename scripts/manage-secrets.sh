#!/bin/bash
# PlanetPlant Secrets Management Script
# Secure storage and retrieval of passwords, tokens, and keys

set -euo pipefail

ACTION="${1:-}"
SECRET_NAME="${2:-}"
SECRET_VALUE="${3:-}"

SECRETS_DIR="/opt/planetplant/backup/secrets"
MASTER_KEY_FILE="$SECRETS_DIR/.master.key"
SECRETS_DB="$SECRETS_DIR/secrets.gpg"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Usage
show_usage() {
    echo "PlanetPlant Secrets Management"
    echo ""
    echo "Usage:"
    echo "  $0 init                           # Initialize secrets store"
    echo "  $0 store <name> <value>           # Store encrypted secret"
    echo "  $0 get <name>                     # Retrieve secret"
    echo "  $0 list                           # List all secret names"
    echo "  $0 delete <name>                  # Delete secret"
    echo "  $0 export                         # Export all secrets (encrypted)"
    echo "  $0 import <file>                  # Import secrets from file"
    echo ""
    echo "Examples:"
    echo "  $0 store influxdb_password 'secure-password-123'"
    echo "  $0 get influxdb_password"
    echo "  $0 store ssh_private_key \"\$(cat ~/.ssh/id_rsa)\""
    echo ""
    echo "Security Features:"
    echo "  🔐 GPG encryption with generated master key"
    echo "  🔑 Key derivation from system entropy"
    echo "  📝 Audit logging for all operations"
    echo "  🚫 No secrets stored in memory longer than necessary"
    exit 1
}

# Function to log operations
log_operation() {
    local operation="$1"
    local secret_name="${2:-}"
    local log_file="/opt/planetplant/logs/secrets-audit.log"
    
    mkdir -p "$(dirname "$log_file")"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$$] $operation $secret_name by $(whoami)" >> "$log_file"
}

# Function to generate master key
generate_master_key() {
    echo "🔑 Generating master encryption key..."
    
    mkdir -p "$SECRETS_DIR"
    chmod 700 "$SECRETS_DIR"
    
    # Generate strong random key
    openssl rand -base64 32 > "$MASTER_KEY_FILE"
    chmod 600 "$MASTER_KEY_FILE"
    
    # Create empty secrets database
    echo "{}" | gpg --symmetric --cipher-algo AES256 \
        --passphrase-file "$MASTER_KEY_FILE" \
        --batch --yes --quiet \
        --output "$SECRETS_DB"
    
    echo "✅ Master key generated and secrets store initialized"
    log_operation "INIT" ""
}

# Function to encrypt and store secret
store_secret() {
    local name="$1"
    local value="$2"
    
    if [ ! -f "$MASTER_KEY_FILE" ]; then
        echo -e "${RED}❌ Secrets store not initialized${NC}"
        echo "Run: $0 init"
        exit 1
    fi
    
    echo "🔐 Storing secret: $name"
    
    # Decrypt existing secrets
    local temp_file="/tmp/secrets_$$"
    gpg --decrypt --passphrase-file "$MASTER_KEY_FILE" \
        --batch --yes --quiet \
        "$SECRETS_DB" > "$temp_file" 2>/dev/null || echo "{}" > "$temp_file"
    
    # Add/update secret
    jq --arg name "$name" --arg value "$value" \
        '. + {($name): {value: $value, created: now, updated: now}}' \
        "$temp_file" > "${temp_file}.new"
    
    # Encrypt and save
    gpg --symmetric --cipher-algo AES256 \
        --passphrase-file "$MASTER_KEY_FILE" \
        --batch --yes --quiet \
        --output "$SECRETS_DB" \
        "${temp_file}.new"
    
    # Cleanup
    shred -u "$temp_file" "${temp_file}.new"
    
    echo "✅ Secret stored successfully"
    log_operation "STORE" "$name"
}

# Function to retrieve secret
get_secret() {
    local name="$1"
    
    if [ ! -f "$SECRETS_DB" ]; then
        echo -e "${RED}❌ No secrets store found${NC}"
        exit 1
    fi
    
    # Decrypt and extract secret
    local secret_value
    secret_value=$(gpg --decrypt --passphrase-file "$MASTER_KEY_FILE" \
        --batch --yes --quiet \
        "$SECRETS_DB" 2>/dev/null | jq -r --arg name "$name" '.[$name].value // empty')
    
    if [ -z "$secret_value" ] || [ "$secret_value" = "null" ]; then
        echo -e "${RED}❌ Secret '$name' not found${NC}"
        exit 1
    fi
    
    echo "$secret_value"
    log_operation "GET" "$name"
}

# Function to list all secrets
list_secrets() {
    if [ ! -f "$SECRETS_DB" ]; then
        echo -e "${YELLOW}No secrets store found${NC}"
        exit 0
    fi
    
    echo "Stored secrets:"
    echo ""
    
    gpg --decrypt --passphrase-file "$MASTER_KEY_FILE" \
        --batch --yes --quiet \
        "$SECRETS_DB" 2>/dev/null | jq -r '
        to_entries[] | 
        "🔑 " + .key + " (updated: " + (.value.updated | strftime("%Y-%m-%d %H:%M:%S")) + ")"'
    
    log_operation "LIST" ""
}

# Function to delete secret
delete_secret() {
    local name="$1"
    
    if [ ! -f "$SECRETS_DB" ]; then
        echo -e "${RED}❌ No secrets store found${NC}"
        exit 1
    fi
    
    echo "🗑️ Deleting secret: $name"
    
    # Decrypt existing secrets
    local temp_file="/tmp/secrets_$$"
    gpg --decrypt --passphrase-file "$MASTER_KEY_FILE" \
        --batch --yes --quiet \
        "$SECRETS_DB" > "$temp_file" 2>/dev/null
    
    # Remove secret
    jq --arg name "$name" 'del(.[$name])' "$temp_file" > "${temp_file}.new"
    
    # Encrypt and save
    gpg --symmetric --cipher-algo AES256 \
        --passphrase-file "$MASTER_KEY_FILE" \
        --batch --yes --quiet \
        --output "$SECRETS_DB" \
        "${temp_file}.new"
    
    # Cleanup
    shred -u "$temp_file" "${temp_file}.new"
    
    echo "✅ Secret deleted successfully"
    log_operation "DELETE" "$name"
}

# Function to export encrypted secrets
export_secrets() {
    local export_file="/opt/planetplant/backup/secrets-export-$(date +%Y%m%d_%H%M%S).gpg"
    
    if [ ! -f "$SECRETS_DB" ]; then
        echo -e "${RED}❌ No secrets store found${NC}"
        exit 1
    fi
    
    echo "📤 Exporting secrets to $export_file"
    
    # Copy encrypted database
    cp "$SECRETS_DB" "$export_file"
    
    # Create export manifest
    local manifest_file="${export_file%.gpg}.manifest"
    cat > "$manifest_file" << EOF
PlanetPlant Secrets Export
=========================
Export Date: $(date)
Master Key: $MASTER_KEY_FILE
Secrets Count: $(gpg --decrypt --passphrase-file "$MASTER_KEY_FILE" --batch --yes --quiet "$SECRETS_DB" 2>/dev/null | jq 'keys | length')

To import on new system:
1. Copy master key: $MASTER_KEY_FILE
2. Copy secrets: $export_file
3. Run: ./manage-secrets.sh import $export_file

WARNING: Keep master key and export file secure!
EOF
    
    echo "✅ Secrets exported successfully"
    echo "📁 Export file: $export_file"
    echo "📋 Manifest: $manifest_file"
    log_operation "EXPORT" "$export_file"
}

# Function to import secrets
import_secrets() {
    local import_file="$1"
    
    if [ ! -f "$import_file" ]; then
        echo -e "${RED}❌ Import file not found: $import_file${NC}"
        exit 1
    fi
    
    echo "📥 Importing secrets from $import_file"
    
    mkdir -p "$SECRETS_DIR"
    chmod 700 "$SECRETS_DIR"
    
    # Copy imported file as new secrets database
    cp "$import_file" "$SECRETS_DB"
    
    echo "✅ Secrets imported successfully"
    echo "⚠️ Ensure master key is available at: $MASTER_KEY_FILE"
    log_operation "IMPORT" "$import_file"
}

# Main function
main() {
    if [ -z "$ACTION" ]; then
        show_usage
    fi
    
    case $ACTION in
        "init")
            if [ -f "$MASTER_KEY_FILE" ]; then
                echo -e "${YELLOW}⚠️ Secrets store already initialized${NC}"
                exit 0
            fi
            generate_master_key
            ;;
        "store")
            if [ -z "$SECRET_NAME" ] || [ -z "$SECRET_VALUE" ]; then
                echo "Usage: $0 store <name> <value>"
                exit 1
            fi
            store_secret "$SECRET_NAME" "$SECRET_VALUE"
            ;;
        "get")
            if [ -z "$SECRET_NAME" ]; then
                echo "Usage: $0 get <name>"
                exit 1
            fi
            get_secret "$SECRET_NAME"
            ;;
        "list")
            list_secrets
            ;;
        "delete")
            if [ -z "$SECRET_NAME" ]; then
                echo "Usage: $0 delete <name>"
                exit 1
            fi
            delete_secret "$SECRET_NAME"
            ;;
        "export")
            export_secrets
            ;;
        "import")
            if [ -z "$SECRET_NAME" ]; then
                echo "Usage: $0 import <file>"
                exit 1
            fi
            import_secrets "$SECRET_NAME"
            ;;
        *)
            echo "Unknown action: $ACTION"
            show_usage
            ;;
    esac
}

# Execute
main
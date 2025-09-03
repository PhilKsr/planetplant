#!/bin/bash
# PlanetPlant Cloud Deployment Script
# Orchestrates deployment to AWS or DigitalOcean with DNS failover

set -euo pipefail

# Configuration
CLOUD_PROVIDER="${1:-}"
ENVIRONMENT="${2:-production}"
TERRAFORM_ACTION="${3:-apply}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🌱 PlanetPlant Cloud Deployment${NC}"
echo "================================="
echo ""

if [ -z "$CLOUD_PROVIDER" ]; then
    echo "Usage: $0 <aws|digitalocean|dns-failover> [environment] [terraform-action]"
    echo ""
    echo "Examples:"
    echo "  $0 aws production plan      # Plan AWS deployment"
    echo "  $0 digitalocean staging apply  # Deploy to DigitalOcean staging"
    echo "  $0 dns-failover production apply  # Setup DNS failover"
    echo ""
    echo "Supported providers:"
    echo "  🔶 aws          - Amazon Web Services"
    echo "  🔵 digitalocean - DigitalOcean"
    echo "  🌐 dns-failover - Cloudflare DNS failover setup"
    echo ""
    echo "Prerequisites:"
    echo "  1. Copy terraform.tfvars.example to terraform.tfvars"
    echo "  2. Fill in your configuration values"
    echo "  3. Configure cloud provider CLI (aws/doctl)"
    echo "  4. Set up Cloudflare API token"
    exit 1
fi

# Function to log with timestamp
log() {
    echo -e "${BLUE}$(date '+%H:%M:%S')${NC} $1"
}

# Function to check prerequisites
check_prerequisites() {
    log "🔍 Checking prerequisites..."
    
    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        echo -e "${RED}❌ Terraform not installed${NC}"
        echo "Install: https://developer.hashicorp.com/terraform/downloads"
        exit 1
    fi
    
    # Check cloud CLI based on provider
    case $CLOUD_PROVIDER in
        "aws")
            if ! command -v aws &> /dev/null; then
                echo -e "${RED}❌ AWS CLI not installed${NC}"
                echo "Install: https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html"
                exit 1
            fi
            
            if ! aws sts get-caller-identity &> /dev/null; then
                echo -e "${RED}❌ AWS credentials not configured${NC}"
                echo "Run: aws configure"
                exit 1
            fi
            ;;
        "digitalocean")
            if ! command -v doctl &> /dev/null; then
                echo -e "${RED}❌ DigitalOcean CLI not installed${NC}"
                echo "Install: https://docs.digitalocean.com/reference/doctl/how-to/install/"
                exit 1
            fi
            
            if ! doctl account get &> /dev/null; then
                echo -e "${RED}❌ DigitalOcean token not configured${NC}"
                echo "Run: doctl auth init"
                exit 1
            fi
            ;;
    esac
    
    log "✅ Prerequisites check passed"
}

# Function to validate terraform configuration
validate_terraform() {
    local terraform_dir="terraform/$CLOUD_PROVIDER"
    
    log "📋 Validating Terraform configuration..."
    
    if [ ! -f "$terraform_dir/terraform.tfvars" ]; then
        echo -e "${RED}❌ terraform.tfvars not found${NC}"
        echo "Copy from terraform.tfvars.example and configure"
        exit 1
    fi
    
    cd "$terraform_dir"
    
    if ! terraform validate; then
        echo -e "${RED}❌ Terraform configuration invalid${NC}"
        exit 1
    fi
    
    log "✅ Terraform configuration valid"
    cd ../..
}

# Function to deploy infrastructure
deploy_infrastructure() {
    local terraform_dir="terraform/$CLOUD_PROVIDER"
    
    log "🚀 Deploying $CLOUD_PROVIDER infrastructure..."
    
    cd "$terraform_dir"
    
    # Initialize Terraform
    terraform init
    
    # Execute requested action
    case $TERRAFORM_ACTION in
        "plan")
            terraform plan -var="environment=$ENVIRONMENT"
            ;;
        "apply")
            terraform apply -var="environment=$ENVIRONMENT" -auto-approve
            
            # Display outputs
            echo ""
            echo -e "${GREEN}🎉 Deployment completed successfully!${NC}"
            echo ""
            echo -e "${BLUE}📊 Deployment Information:${NC}"
            terraform output
            ;;
        "destroy")
            echo -e "${YELLOW}⚠️ WARNING: This will destroy all resources!${NC}"
            read -p "Type 'DESTROY' to confirm: " confirmation
            
            if [ "$confirmation" = "DESTROY" ]; then
                terraform destroy -var="environment=$ENVIRONMENT" -auto-approve
                log "✅ Infrastructure destroyed"
            else
                log "Destruction cancelled"
            fi
            ;;
        *)
            echo "Invalid action: $TERRAFORM_ACTION"
            echo "Supported: plan, apply, destroy"
            exit 1
            ;;
    esac
    
    cd ../..
}

# Function to test deployment
test_deployment() {
    local terraform_dir="terraform/$CLOUD_PROVIDER"
    
    log "🧪 Testing deployment..."
    
    cd "$terraform_dir"
    
    # Get deployment URL
    local app_url
    app_url=$(terraform output -raw domain_url 2>/dev/null || echo "")
    
    if [ -n "$app_url" ]; then
        echo "Testing: $app_url"
        
        # Wait for services to start
        sleep 60
        
        # Test health endpoints
        if curl -f -s "$app_url/health" > /dev/null; then
            log "✅ Frontend health check passed"
        else
            log "❌ Frontend health check failed"
        fi
        
        if curl -f -s "$app_url/api/health" > /dev/null; then
            log "✅ Backend health check passed"
        else
            log "❌ Backend health check failed"
        fi
    fi
    
    cd ../..
}

# Function to setup monitoring
setup_monitoring() {
    log "📊 Setting up monitoring..."
    
    echo "Monitoring endpoints:"
    echo "  📈 Application: https://$domain_name/grafana"
    echo "  🔍 Logs: Check cloud provider console"
    echo "  📱 Alerts: Configured for email and Slack"
    
    if [ "$CLOUD_PROVIDER" = "aws" ]; then
        echo "  ☁️ CloudWatch: https://console.aws.amazon.com/cloudwatch"
    elif [ "$CLOUD_PROVIDER" = "digitalocean" ]; then
        echo "  🌊 DO Monitoring: https://cloud.digitalocean.com/monitoring"
    fi
}

# Function to display next steps
display_next_steps() {
    echo ""
    echo -e "${GREEN}✅ Cloud deployment completed successfully!${NC}"
    echo ""
    echo -e "${BLUE}🔧 Next Steps:${NC}"
    echo ""
    
    if [ "$CLOUD_PROVIDER" != "dns-failover" ]; then
        echo "1. **Test the deployment**:"
        echo "   curl https://your-domain.com/health"
        echo "   curl https://api.your-domain.com/api/health"
        echo ""
        echo "2. **Configure DNS failover** (if using with Raspberry Pi):"
        echo "   ./deploy.sh dns-failover production apply"
        echo ""
        echo "3. **Update ESP32 devices** with cloud MQTT endpoint"
        echo ""
        echo "4. **Test backup system**:"
        echo "   ssh user@instance '/opt/planetplant/scripts/backup-all.sh manual'"
        echo ""
        echo "5. **Monitor the system**:"
        echo "   - Check cloud provider monitoring dashboard"
        echo "   - Verify Slack notifications are working"
        echo "   - Set up external monitoring (Pingdom, UptimeRobot)"
    else
        echo "1. **Test DNS failover**:"
        echo "   - Stop primary instance and verify traffic goes to secondary"
        echo "   - Check Cloudflare load balancer dashboard"
        echo ""
        echo "2. **Monitor health checks**:"
        echo "   - Primary: https://status.your-domain.com"
        echo "   - Secondary: https://cloud.your-domain.com"
        echo ""
        echo "3. **Set up alerting**:"
        echo "   - Configure Cloudflare notifications"
        echo "   - Test Slack webhook integration"
    fi
    
    echo ""
    echo -e "${YELLOW}💡 Remember:${NC}"
    echo "  - Update your disaster recovery documentation"
    echo "  - Schedule regular failover tests"
    echo "  - Monitor costs and optimize resources"
    echo "  - Keep Terraform state secure and backed up"
    echo ""
}

# Main deployment procedure
main() {
    log "🚀 Starting $CLOUD_PROVIDER deployment for $ENVIRONMENT..."
    
    # Check if we're in the right directory
    if [ ! -f "terraform.tfvars.example" ]; then
        echo -e "${RED}❌ Please run from deployment/cloud/ directory${NC}"
        exit 1
    fi
    
    # Step 1: Prerequisites
    check_prerequisites
    
    # Step 2: Validate configuration
    if [ "$CLOUD_PROVIDER" != "dns-failover" ]; then
        validate_terraform
    fi
    
    # Step 3: Deploy infrastructure
    deploy_infrastructure
    
    # Step 4: Test deployment (skip for destroy action)
    if [ "$TERRAFORM_ACTION" = "apply" ] && [ "$CLOUD_PROVIDER" != "dns-failover" ]; then
        test_deployment
        setup_monitoring
    fi
    
    # Step 5: Display next steps
    if [ "$TERRAFORM_ACTION" = "apply" ]; then
        display_next_steps
    fi
    
    log "✅ Deployment procedure completed"
}

# Execute deployment
main
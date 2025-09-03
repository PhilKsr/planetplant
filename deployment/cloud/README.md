# PlanetPlant Cloud Deployment

Cloud deployment configurations for AWS and DigitalOcean with automated DNS failover.

## Architecture

```
┌─────────────────┐    ┌─────────────────┐
│  Raspberry Pi   │    │   Cloud (AWS/DO) │
│   (Primary)     │    │   (Secondary)    │
│                 │    │                 │
│ ┌─────────────┐ │    │ ┌─────────────┐ │
│ │   Frontend  │ │    │ │   Frontend  │ │
│ │   Backend   │ │    │ │   Backend   │ │
│ │   InfluxDB  │ │    │ │   InfluxDB  │ │
│ │   Redis     │ │    │ │   Redis     │ │
│ │   MQTT      │ │    │ │   MQTT      │ │
│ └─────────────┘ │    │ └─────────────┘ │
└─────────────────┘    └─────────────────┘
         │                       │
         └───────────┬───────────┘
                     │
            ┌─────────────────┐
            │   Cloudflare    │
            │  DNS Failover   │
            │  Load Balancer  │
            └─────────────────┘
```

## Quick Start

### Prerequisites
- Terraform >= 1.5
- AWS CLI (for AWS deployment)
- DigitalOcean CLI (for DO deployment)
- Cloudflare account with domain management

### 1. AWS Deployment

```bash
cd deployment/cloud/terraform/aws

# Configure variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

# Deploy infrastructure
terraform init
terraform plan
terraform apply

# Get outputs
terraform output domain_url
terraform output ssh_command
```

### 2. DigitalOcean Deployment

```bash
cd deployment/cloud/terraform/digitalocean

# Configure variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

# Deploy infrastructure
terraform init
terraform plan
terraform apply

# Get outputs
terraform output domain_url
terraform output ssh_command
```

### 3. DNS Failover Setup

```bash
cd deployment/cloud/terraform/dns-failover

# Configure variables with both primary and secondary IPs
cp terraform.tfvars.example terraform.tfvars
# Edit with your Raspberry Pi and cloud IPs

# Deploy DNS failover
terraform init
terraform plan
terraform apply
```

## Configuration Files

### Environment Variables

Create `terraform.tfvars` in each terraform directory:

```hcl
# AWS example
aws_region = "us-east-1"
domain_name = "your-domain.com"
environment = "production"

# Secrets
influxdb_password = "your-secure-password"
influxdb_token = "your-influxdb-token"
redis_password = "your-redis-password"
jwt_secret = "your-jwt-secret"
grafana_password = "your-grafana-password"

# SSH
public_key = "ssh-rsa AAAAB3NzaC1yc2E..."

# Notifications
alert_email = "admin@your-domain.com"
slack_webhook = "https://hooks.slack.com/..."

# Cloudflare
cloudflare_zone_id = "your-zone-id"
cloudflare_api_token = "your-api-token"
```

### Docker Compose Files

- `docker-compose.aws.yml` - AWS-optimized configuration with S3 backups
- `docker-compose.digitalocean.yml` - DigitalOcean-optimized with Spaces backups

## Features

### AWS Deployment
- **Auto Scaling Group** with health checks
- **Application Load Balancer** with SSL termination
- **S3 backups** with lifecycle management
- **CloudWatch monitoring** and alerts
- **IAM roles** with least privilege
- **VPC** with security groups

### DigitalOcean Deployment
- **Load Balancer** with health checks
- **Spaces backups** with versioning
- **Monitoring alerts** and uptime checks
- **Reserved IP** for static addressing
- **Firewall** with port restrictions
- **Optional App Platform** deployment

### DNS Failover
- **Health checks** for both primary and secondary
- **Automatic failover** when primary is down
- **Geographic routing** for optimal performance
- **Rate limiting** and WAF protection
- **Monitoring endpoints** for direct access

## Disaster Recovery Integration

The cloud deployment integrates with the disaster recovery procedures:

1. **Automated Backups** - Cloud instances backup to S3/Spaces
2. **Cross-Region Sync** - Backup repositories can sync between Pi and cloud
3. **Failover Testing** - Monthly automated failover tests
4. **Emergency Deployment** - Rapid cloud deployment for emergencies

### Emergency Cloud Deployment

```bash
# Deploy emergency cloud instance (AWS)
cd deployment/cloud/terraform/aws
terraform apply -auto-approve

# Restore from Pi backup
ssh ubuntu@$(terraform output -raw droplet_ip)
sudo /opt/planetplant/scripts/emergency-restore.sh auto latest

# Update DNS to point to cloud
cd ../dns-failover
terraform apply -var="primary_ip=$(terraform output -raw droplet_ip)"
```

## Monitoring

### Health Endpoints
- **Frontend**: `GET /health` (returns 200 "healthy")
- **Backend**: `GET /api/health` (JSON status)
- **InfluxDB**: `GET /ping` (returns 204)

### Alerting
- **High CPU/Memory** usage alerts
- **Service downtime** notifications
- **Backup failure** alerts
- **Disk space** warnings

### Logs
- **Application logs** → CloudWatch/DigitalOcean Monitoring
- **Access logs** → Load balancer logs
- **System logs** → Centralized logging

## Cost Optimization

### AWS
- Use **t3.medium** instances (2 vCPU, 4GB RAM) - ~$30/month
- **S3 Standard-IA** for backups - ~$5/month for 100GB
- **ALB** with minimal data transfer - ~$20/month

### DigitalOcean
- Use **s-2vcpu-4gb** droplets - $24/month
- **Spaces** storage - $5/month for 250GB
- **Load Balancer** - $10/month

### Total Monthly Cost
- **Primary (Pi)**: $80 (hardware) + $0 (electricity/internet)
- **Secondary (Cloud)**: $35-60/month
- **DNS/CDN**: $0-20/month (Cloudflare Pro)

## Security

### Network Security
- **Firewall rules** restrict access to required ports only
- **VPC/Private networks** isolate services
- **SSH key authentication** only
- **Fail2ban** for SSH brute force protection

### Application Security
- **HTTPS only** with automatic HTTP→HTTPS redirect
- **Rate limiting** on API endpoints
- **WAF rules** for common attacks
- **Secrets management** via environment variables

### Backup Security
- **Encrypted backups** with Restic
- **IAM roles** with minimal permissions
- **Versioned storage** with retention policies
- **Access logging** for audit trails

## Troubleshooting

### Common Issues

1. **Health check failures**
   ```bash
   # Check service status
   ssh user@instance "docker ps"
   ssh user@instance "curl -f http://localhost/health"
   ```

2. **DNS failover not working**
   ```bash
   # Check health checks
   curl -H "CF-Connecting-IP: test" https://api.cloudflare.com/client/v4/zones/ZONE_ID/healthchecks
   ```

3. **Backup failures**
   ```bash
   # Check backup logs
   ssh user@instance "cat /opt/planetplant/logs/backup.log"
   ```

### Rollback Procedures

1. **Infrastructure rollback**
   ```bash
   terraform destroy
   ```

2. **DNS rollback**
   ```bash
   cd dns-failover
   terraform destroy
   ```

3. **Service rollback**
   ```bash
   ssh user@instance "cd /opt/planetplant && docker compose down"
   ssh user@instance "docker image prune -f"
   ```
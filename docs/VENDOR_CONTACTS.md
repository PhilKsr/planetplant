# PlanetPlant Vendor Contacts & Hardware Information

## 🚨 Emergency Contacts

### Immediate Response (24/7)
- **Primary Admin**: admin@planetplant.local
- **Technical Lead**: tech@planetplant.local  
- **Emergency Phone**: +49-xxx-xxx-xxxx

### Escalation Chain
1. **Level 1** (0-30 min): Technical team self-resolution
2. **Level 2** (30-60 min): Vendor support engagement
3. **Level 3** (60+ min): Management notification and external contractors

## 🏢 Critical Vendors & Suppliers

### Cloud Infrastructure

#### Amazon Web Services (AWS)
- **Support Level**: Business Support
- **Support Portal**: https://console.aws.amazon.com/support/
- **Phone**: +1 (206) 266-4064
- **Chat**: Available 24/7 via AWS Console
- **Account ID**: [Store in secrets: `aws_account_id`]
- **Emergency Escalation**: Premium Support (upgrade available)

#### DigitalOcean
- **Support Level**: Standard
- **Support Portal**: https://cloud.digitalocean.com/support
- **Email**: support@digitalocean.com
- **Emergency Contact**: Available via ticket system only
- **Account ID**: [Store in secrets: `do_account_id`]

#### Cloudflare
- **Support Level**: Pro Plan
- **Support Portal**: https://dash.cloudflare.com/support
- **Email**: support@cloudflare.com
- **Phone**: Available for Business/Enterprise plans
- **Zone ID**: [Store in secrets: `cloudflare_zone_id`]
- **API Access**: Emergency API tokens available

### Hardware Suppliers

#### Raspberry Pi Foundation
- **Website**: https://www.raspberrypi.org/
- **Support**: https://www.raspberrypi.org/forums/
- **Authorized Distributors**:
  - **Germany**: Conrad Electronic, reichelt elektronik
  - **USA**: Adafruit, SparkFun
  - **Global**: element14, RS Components

#### ESP32 Hardware (Espressif)
- **Website**: https://www.espressif.com/
- **Support**: https://esp32.com/
- **GitHub**: https://github.com/espressif/esp-idf
- **Community**: https://esp32.com/

#### Sensors & Components
- **Moisture Sensors**: Capacitive soil moisture sensor v2.0
  - Supplier: AliExpress, Amazon, Adafruit
  - Part Number: Various (compatible with 3.3V ADC)
- **Water Pumps**: 12V DC submersible pumps
  - Supplier: Local aquarium supply stores
  - Specifications: 3-5W, food-safe materials
- **Relays**: 5V relay modules with optocoupler isolation
  - Supplier: Arduino component kits

### Software & Services

#### Grafana Labs
- **Support**: https://grafana.com/support/
- **Documentation**: https://grafana.com/docs/
- **Community**: https://community.grafana.com/
- **Emergency**: Enterprise support available

#### InfluxDB (InfluxData)
- **Support**: https://support.influxdata.com/
- **Documentation**: https://docs.influxdata.com/
- **Community**: https://community.influxdata.com/
- **Version**: 2.7 (current stable)

#### Docker Inc.
- **Support**: https://support.docker.com/
- **Documentation**: https://docs.docker.com/
- **Status Page**: https://status.docker.com/

### Internet & Connectivity

#### Internet Service Provider
- **Provider**: [Your ISP Name]
- **Account Number**: [Store in secrets: `isp_account`]
- **Technical Support**: [Your ISP tech support]
- **Emergency Line**: [Your ISP emergency contact]

#### Domain Registrar
- **Registrar**: [Your domain registrar]
- **Account**: [Store in secrets: `domain_account`]
- **Support**: [Registrar support contact]
- **Renewal Date**: [Domain expiration date]

## 🔧 Hardware Replacement Parts

### Critical Components (Keep in Stock)

#### Raspberry Pi 5 (Primary System)
- **Model**: Raspberry Pi 5 8GB RAM
- **Supplier**: Official distributors
- **Lead Time**: 2-4 weeks
- **Backup**: Raspberry Pi 4 8GB (compatible fallback)
- **Storage**: MicroSD cards (Class 10, 64GB minimum)
- **Power**: Official 27W USB-C power supply

#### ESP32 Controllers
- **Primary**: ESP32-WROOM-32 development boards
- **Quantity**: Keep 2-3 spare units
- **Programming**: USB-C cables for flashing
- **Expansion**: Breadboards and jumper wires

#### Sensors (Replacement Stock)
- **Moisture Sensors**: 5x capacitive soil moisture sensors
- **Temperature/Humidity**: 3x DHT22 or SHT30 sensors  
- **Light Sensors**: 3x BH1750 light intensity sensors
- **Water Level**: 2x ultrasonic sensors (HC-SR04)

#### Power & Connectivity
- **Power Supplies**: 12V 2A adapters for pumps
- **Network**: Ethernet cables (Cat6, various lengths)
- **Storage**: USB flash drives for emergency backups
- **Enclosures**: Waterproof cases for outdoor sensors

### Component Specifications

#### Raspberry Pi 5 System
```
CPU: Broadcom BCM2712 (ARM Cortex-A76)
RAM: 8GB LPDDR4X
Storage: 64GB microSD (SanDisk Extreme Pro recommended)
Network: Gigabit Ethernet + WiFi 6
Power: 5V 5A USB-C (27W official supply)
GPIO: 40-pin compatible with Pi 4
Operating System: Raspberry Pi OS 64-bit
```

#### ESP32 Development Board
```
CPU: Xtensa LX6 dual-core @ 240MHz
RAM: 520KB SRAM
Storage: 4MB Flash
Network: WiFi 802.11n + Bluetooth 4.2
GPIO: 30 usable pins
ADC: 12-bit, up to 18 channels
Operating Voltage: 3.3V
Programming: Arduino IDE or PlatformIO
```

#### Sensor Specifications
```
Moisture Sensor:
- Type: Capacitive (corrosion resistant)
- Voltage: 3.3V compatible
- Output: Analog 0-3.3V
- Range: 0-100% soil moisture

Temperature/Humidity (DHT22):
- Range: -40°C to 80°C, 0-100% RH
- Accuracy: ±0.5°C, ±2% RH
- Interface: Single-wire digital

Water Pump:
- Voltage: 12V DC
- Power: 3-5W
- Flow Rate: 1-3L/min
- Materials: Food-safe plastic/stainless steel
```

## 🔐 Secure Password Storage

### Initialize Secrets Management

```bash
# Initialize encrypted secrets store
sudo /opt/planetplant/scripts/manage-secrets.sh init

# Store critical passwords
sudo /opt/planetplant/scripts/manage-secrets.sh store influxdb_password "your-secure-password"
sudo /opt/planetplant/scripts/manage-secrets.sh store influxdb_token "your-influxdb-token"
sudo /opt/planetplant/scripts/manage-secrets.sh store redis_password "your-redis-password"
sudo /opt/planetplant/scripts/manage-secrets.sh store jwt_secret "your-jwt-secret"
sudo /opt/planetplant/scripts/manage-secrets.sh store grafana_password "your-grafana-password"

# Store API tokens
sudo /opt/planetplant/scripts/manage-secrets.sh store slack_webhook "https://hooks.slack.com/..."
sudo /opt/planetplant/scripts/manage-secrets.sh store cloudflare_api_token "your-cloudflare-token"
sudo /opt/planetplant/scripts/manage-secrets.sh store aws_access_key "AKIA..."
sudo /opt/planetplant/scripts/manage-secrets.sh store aws_secret_key "..."
sudo /opt/planetplant/scripts/manage-secrets.sh store do_api_token "dop_v1_..."

# Store SSH keys
sudo /opt/planetplant/scripts/manage-secrets.sh store ssh_private_key "$(cat ~/.ssh/id_rsa)"
sudo /opt/planetplant/scripts/manage-secrets.sh store ssh_public_key "$(cat ~/.ssh/id_rsa.pub)"

# Store account information
sudo /opt/planetplant/scripts/manage-secrets.sh store aws_account_id "123456789012"
sudo /opt/planetplant/scripts/manage-secrets.sh store do_account_id "your-do-account-id"
sudo /opt/planetplant/scripts/manage-secrets.sh store domain_registrar_login "user:password"
```

### Retrieve Secrets During Recovery

```bash
# Get secret during emergency
INFLUXDB_TOKEN=$(sudo /opt/planetplant/scripts/manage-secrets.sh get influxdb_token)

# List all available secrets
sudo /opt/planetplant/scripts/manage-secrets.sh list

# Export for migration
sudo /opt/planetplant/scripts/manage-secrets.sh export
```

## 📞 Vendor Support Procedures

### AWS Support Escalation

1. **Business Hours** (Non-Critical):
   - Login to AWS Console → Support → Create Case
   - Select appropriate severity level
   - Include account ID and affected resources

2. **After Hours** (Critical):
   - Phone: +1 (206) 266-4064
   - Have account ID ready: [From secrets store]
   - Reference Support Plan: Business Support

3. **Critical Outage**:
   - Escalate to Premium Support (temporary upgrade available)
   - Provide impact assessment and business justification

### DigitalOcean Support Process

1. **Standard Issues**:
   - Create ticket via DigitalOcean Control Panel
   - Include droplet ID and detailed description
   - Expected response: 4-6 hours

2. **Critical Issues**:
   - Mark ticket as "Critical" priority
   - Include system logs and error messages
   - Follow up via social media if no response in 2 hours

### Cloudflare Emergency Support

1. **DNS Issues**:
   - Check Cloudflare status page: https://www.cloudflarestatus.com/
   - Use Cloudflare Community: https://community.cloudflare.com/
   - Emergency: Tweet @CloudflareHelp with account details

2. **Load Balancer Issues**:
   - Access Cloudflare API directly for status
   - Disable load balancer and use direct DNS if needed
   - Document all changes for post-incident review

## 🛒 Hardware Ordering Information

### Priority Suppliers (Germany/EU)

#### Conrad Electronic
- **Website**: https://www.conrad.de/
- **Phone**: +49 (0) 9604 40-0
- **Delivery**: 1-2 days within Germany
- **Account**: [Store in secrets: `conrad_account`]

#### reichelt elektronik
- **Website**: https://www.reichelt.de/
- **Phone**: +49 (0) 4422 955-333
- **Delivery**: Next-day available
- **Account**: [Store in secrets: `reichelt_account`]

#### element14 (Farnell)
- **Website**: https://de.farnell.com/
- **Phone**: +49 (0) 89 61 39 39 39
- **Delivery**: Same-day in major cities
- **Account**: [Store in secrets: `element14_account`]

### Emergency Procurement Process

1. **Immediate Need** (Same Day):
   - Contact local electronics stores
   - Use Amazon Prime for standard components
   - Conrad/reichelt same-day delivery (major cities)

2. **Standard Replacement** (1-3 Days):
   - Order through established accounts
   - Use expedited shipping
   - Verify part numbers against compatibility list

3. **Bulk Replacement** (Planning):
   - Quarterly review of stock levels
   - Volume discounts for sensor bulk orders
   - Coordinate with project timeline

## 📋 Maintenance Contracts

### Current Service Agreements

#### Internet Connectivity
- **Provider**: [Your ISP]
- **SLA**: 99.5% uptime
- **Support Response**: 4 hours
- **Backup Connection**: Mobile hotspot available

#### Power Supply
- **Utility**: [Your power company]
- **UPS System**: [Describe your UPS setup]
- **Backup Power**: [Generator/battery backup details]

### Recommended Additional Contracts

1. **Hardware Warranty Extensions**:
   - Extended warranty for Raspberry Pi systems
   - Component replacement insurance
   - Expedited shipping agreements

2. **Professional Services**:
   - On-call electronics technician
   - Network infrastructure specialist
   - Emergency cloud migration services

## 📊 Cost Planning

### Emergency Replacement Budget

| Component | Quantity | Unit Cost | Total Cost | Lead Time |
|-----------|----------|-----------|------------|-----------|
| Raspberry Pi 5 8GB | 1 | €90 | €90 | 2-4 weeks |
| MicroSD Cards | 3 | €15 | €45 | 1-2 days |
| ESP32 Boards | 3 | €8 | €24 | 1-2 days |
| Moisture Sensors | 5 | €3 | €15 | 1 week |
| Water Pumps | 2 | €12 | €24 | 1 week |
| Power Supplies | 2 | €25 | €50 | 1-2 days |
| Cables & Connectors | Various | €30 | €30 | 1-2 days |

**Total Emergency Stock**: €278

### Annual Service Costs

| Service | Monthly Cost | Annual Cost | Notes |
|---------|--------------|-------------|--------|
| Cloud Backup (AWS S3) | €5 | €60 | 100GB backup storage |
| Cloud Standby (DO) | €24 | €288 | s-2vcpu-4gb droplet |
| Cloudflare Pro | €17 | €204 | Advanced security & analytics |
| Domain Registration | €2 | €24 | .com domain renewal |
| Monitoring Services | €8 | €96 | External uptime monitoring |

**Total Annual Cloud Costs**: €672

## 📞 Emergency Contact Card

Print and keep accessible:

```
═══════════════════════════════════════
      PLANETPLANT EMERGENCY CONTACTS
═══════════════════════════════════════

🚨 CRITICAL SYSTEM FAILURE:
   1. Check status: https://status.your-domain.com
   2. Emergency restore: sudo emergency-restore.sh
   3. Call primary admin: +49-xxx-xxx-xxxx

🌐 INTERNET/DNS ISSUES:
   - ISP Emergency: [Your ISP number]
   - Cloudflare Status: cloudflarestatus.com
   - Backup DNS: 8.8.8.8, 1.1.1.1

💾 DATA RECOVERY:
   - Latest backup location: /opt/planetplant/backups
   - Restic password: [Check secrets store]
   - Cloud backup: AWS S3 / DO Spaces

🔌 HARDWARE FAILURE:
   - Component supplier: Conrad +49-9604-40-0
   - Express delivery: element14 +49-89-6139-3939
   - Local electronics: [Your local store]

📱 NOTIFICATION CHANNELS:
   - Slack: #planetplant-alerts
   - Email: admin@planetplant.local
   - SMS: [Configure via monitoring service]

🔐 ACCESS RECOVERY:
   - SSH keys: /opt/planetplant/backup/secrets
   - Admin passwords: sudo manage-secrets.sh get
   - Emergency access: [Physical console access]

═══════════════════════════════════════
      Last updated: $(date +%Y-%m-%d)
═══════════════════════════════════════
```

## 🛠️ Technical Support Scripts

### Vendor Information Retrieval

```bash
#!/bin/bash
# Get all vendor contact information quickly

echo "🏢 VENDOR EMERGENCY CONTACTS"
echo "============================"
echo ""

echo "☁️ Cloud Providers:"
echo "  AWS Support: +1-206-266-4064"
echo "  DigitalOcean: support@digitalocean.com"
echo "  Cloudflare: support@cloudflare.com"
echo ""

echo "🔧 Hardware Suppliers:"
echo "  Conrad Electronic: +49-9604-40-0"
echo "  reichelt elektronik: +49-4422-955-333"
echo "  element14: +49-89-6139-3939"
echo ""

echo "🌐 Infrastructure:"
echo "  ISP Emergency: [Configure]"
echo "  Domain Registrar: [Configure]"
echo "  Power Company: [Configure]"
```

### Hardware Information Lookup

```bash
#!/bin/bash
# Quick hardware information for support calls

echo "🖥️ HARDWARE INFORMATION"
echo "======================"
echo ""

echo "Primary System:"
echo "  Model: $(cat /proc/device-tree/model 2>/dev/null || echo 'Unknown')"
echo "  Serial: $(cat /proc/cpuinfo | grep Serial | cut -d ' ' -f 2)"
echo "  OS: $(lsb_release -d | cut -f2)"
echo "  Kernel: $(uname -r)"
echo ""

echo "Storage:"
echo "  Root: $(df -h / | tail -1 | awk '{print $2 " (" $5 " used)"}')"
echo "  Data: $(df -h /opt/planetplant 2>/dev/null | tail -1 | awk '{print $2 " (" $5 " used)"}' || echo 'Not mounted')"
echo ""

echo "Network:"
echo "  Hostname: $(hostname)"
echo "  Local IP: $(hostname -I | awk '{print $1}')"
echo "  Public IP: $(curl -s -m 5 ifconfig.me 2>/dev/null || echo 'Unknown')"
echo "  DNS: $(cat /etc/resolv.conf | grep nameserver | head -1 | awk '{print $2}')"
echo ""

echo "Services:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep planetplant
```

## 📋 Vendor SLA Summary

| Vendor | Support Level | Response Time | Availability | Escalation |
|--------|---------------|---------------|--------------|------------|
| AWS | Business | 1-4 hours | 24/7 | Phone/Chat |
| DigitalOcean | Standard | 4-8 hours | 24/7 | Ticket only |
| Cloudflare | Pro | 2-6 hours | 24/7 | Email/Community |
| Local ISP | Standard | 4-24 hours | Business hours | Phone |
| Hardware Suppliers | Standard | 1-2 days | Business hours | Phone/Email |

## 🎯 Support Strategy

### Critical (P0) - System Down
1. **0-15 min**: Internal troubleshooting and emergency restore
2. **15-30 min**: Activate cloud failover if available  
3. **30-45 min**: Contact vendor support for infrastructure issues
4. **45-60 min**: Escalate to management and consider external help

### High (P1) - Degraded Performance
1. **0-30 min**: Identify root cause and implement workaround
2. **30-60 min**: Contact appropriate vendor for resolution
3. **1-4 hours**: Implement permanent fix with vendor guidance

### Medium (P2) - Planned Maintenance
1. Schedule during maintenance windows
2. Coordinate with vendors for major updates
3. Use staging environment for testing

### Low (P3) - Enhancement Requests
1. Evaluate cost/benefit with vendors
2. Schedule for next maintenance cycle
3. Consider community/open source alternatives
# 🚨 PlanetPlant Disaster Recovery Plan

## 📋 Recovery Time Objectives (RTO/RPO)

| Scenario | RTO (Recovery Time) | RPO (Data Loss) | Priority |
|----------|--------------------|--------------------|----------|
| **Service Restart** | 5 minutes | 0 minutes | P1 |
| **Container Failure** | 15 minutes | 0 minutes | P1 |
| **Database Corruption** | 30 minutes | 24 hours | P2 |
| **Pi Hardware Failure** | 1 hour | 24 hours | P2 |
| **Complete System Loss** | 4 hours | 24 hours | P3 |
| **Building/Fire/Flood** | 8 hours | 24 hours | P3 |

## 🚨 Emergency Response Procedures

### Immediate Actions (0-15 minutes)
1. **Assess the situation** - What services are down?
2. **Check monitoring** - Uptime Kuma, Grafana alerts
3. **Basic troubleshooting** - Restart services if needed
4. **Escalate if needed** - Contact technical lead

### Recovery Actions (15-60 minutes)
1. **Identify root cause** - Check logs, system resources
2. **Execute recovery plan** - Run appropriate recovery script
3. **Verify recovery** - Health checks and functionality tests
4. **Document incident** - Update incident log

### Post-Recovery (60+ minutes)
1. **Full system verification** - End-to-end testing
2. **Backup verification** - Ensure backups are current
3. **Incident review** - What went wrong and how to prevent
4. **Update procedures** - Improve based on lessons learned

## 👥 Emergency Contact List

### Primary Contacts
| Role | Name | Phone | Email | Responsibility |
|------|------|-------|--------|----------------|
| **Technical Lead** | [Name] | [+49 xxx] | [email] | System architecture, critical decisions |
| **DevOps Engineer** | [Name] | [+49 xxx] | [email] | Infrastructure, deployments, monitoring |
| **On-Call Engineer** | [Name] | [+49 xxx] | [email] | First response, basic troubleshooting |

### Escalation Path
1. **Level 1:** On-Call Engineer (0-15 min response)
2. **Level 2:** DevOps Engineer (15-30 min response)
3. **Level 3:** Technical Lead (30-60 min response)
4. **Level 4:** External consultant/vendor support

### Vendor Contacts
| Service | Contact | Phone | Email | Support Level |
|---------|---------|-------|--------|---------------|
| **Internet Provider** | [ISP] | [Phone] | [Email] | 24/7 |
| **Hardware Vendor** | Raspberry Pi Foundation | - | support@raspberrypi.org | Business hours |
| **Cloud Provider** | AWS/DigitalOcean | - | support@ | 24/7 Premium |

## 🔧 Recovery Scenarios & Procedures

### Scenario 1: Single Service Failure
**Symptoms:** One service (backend, frontend, database) not responding
**RTO:** 5 minutes | **RPO:** 0 minutes

```bash
# 1. Check service status
docker ps | grep planetplant
docker compose logs [service-name]

# 2. Restart specific service
docker compose restart [service-name]

# 3. Verify health
curl http://localhost:3001/api/health
curl http://localhost/health

# 4. If restart fails, recreate container
docker compose up -d --force-recreate [service-name]
```

### Scenario 2: Database Corruption
**Symptoms:** InfluxDB errors, data inconsistencies
**RTO:** 30 minutes | **RPO:** 24 hours

```bash
# 1. Stop services accessing database
docker compose stop backend grafana

# 2. Check InfluxDB status
docker exec planetplant-influxdb influx ping

# 3. Attempt database repair
docker exec planetplant-influxdb influx backup /tmp/emergency-backup
docker exec planetplant-influxdb influx restore /tmp/emergency-backup

# 4. If repair fails, restore from backup
sudo /opt/planetplant/scripts/restore-backup.sh --latest

# 5. Restart all services
docker compose up -d

# 6. Verify data integrity
curl http://localhost:3001/api/plants
```

### Scenario 3: Raspberry Pi Hardware Failure
**Symptoms:** Pi won't boot, hardware errors, corruption
**RTO:** 1 hour | **RPO:** 24 hours

```bash
# 1. Prepare replacement hardware
# - New Raspberry Pi 5 (8GB recommended)
# - New SD card (64GB+, Class 10)
# - Same network setup

# 2. Flash fresh Raspberry Pi OS
# Use Raspberry Pi Imager with SSH enabled

# 3. Run migration script
sudo /opt/planetplant/scripts/migrate-to-new-pi.sh

# 4. Restore from latest backup
sudo /opt/planetplant/scripts/restore-backup.sh --latest

# 5. Update DNS/IP addresses if changed
# Update plant configuration, monitoring URLs
```

### Scenario 4: Complete Site Loss
**Symptoms:** Building fire, flood, theft
**RTO:** 4-8 hours | **RPO:** 24 hours

```bash
# 1. Deploy to cloud as emergency fallback
cd deployment/cloud
terraform init
terraform apply -var="emergency_mode=true"

# 2. Restore from cloud backups
./scripts/cloud-emergency-restore.sh

# 3. Update DNS to point to cloud instance
# 4. Notify users of temporary cloud deployment
# 5. Plan return to on-premises when possible
```

## 🛠️ Recovery Tools & Scripts

### Emergency Scripts Location
All recovery scripts are located in `/opt/planetplant/scripts/`:

| Script | Purpose | Usage |
|--------|---------|--------|
| `emergency-restore.sh` | Fast emergency recovery | `sudo ./emergency-restore.sh` |
| `migrate-to-new-pi.sh` | Hardware migration | `sudo ./migrate-to-new-pi.sh <backup-id>` |
| `export-all-data.sh` | Complete data export | `./export-all-data.sh [target-dir]` |
| `restore-backup.sh` | Interactive restore | `sudo ./restore-backup.sh` |
| `backup-status.sh` | Check backup health | `./backup-status.sh` |

### Quick Recovery Commands

```bash
# Check system status
curl http://localhost:3001/api/health | jq

# Restart all services
cd /opt/planetplant && docker compose restart

# Check latest backup
restic -r /opt/planetplant/backups/restic-repo snapshots --last 1

# Emergency backup now
/opt/planetplant/scripts/backup-all.sh manual

# View service logs
docker compose logs --tail=50 -f

# Check resource usage
docker stats --no-stream
```

## 🔐 Critical Information Vault

### Environment Variables (Encrypted)
**Location:** `/opt/planetplant/secrets/emergency-config.gpg`

```bash
# Decrypt emergency config
gpg --decrypt /opt/planetplant/secrets/emergency-config.gpg > /tmp/emergency.env
source /tmp/emergency.env
```

**Contents:**
- InfluxDB Admin Token
- JWT Secret Keys
- Cloud Storage Credentials
- SMTP Passwords
- Webhook Secrets

### Service Credentials
| Service | Username | Password Location | Notes |
|---------|----------|-------------------|--------|
| **InfluxDB** | admin | `.env` | `INFLUXDB_PASSWORD` |
| **Grafana** | admin | `.env` | `GRAFANA_ADMIN_PASSWORD` |
| **Redis** | - | `.env` | `REDIS_PASSWORD` |
| **Portainer** | admin | Install script | `PORTAINER_PASSWORD` |
| **Uptime Kuma** | admin | Setup script | Auto-generated |

### Important URLs
- **Production:** http://[PI-IP]
- **Staging:** http://[PI-IP]:8080
- **Monitoring:** http://[PI-IP]:3005/status
- **Management:** http://[PI-IP]:9000
- **Cloud Backup:** [Provider-specific URL]

## 📊 Backup Verification Procedures

### Daily Verification (Automated)
```bash
# Runs automatically via cron at 05:00
/opt/planetplant/scripts/verify-backup-integrity.sh daily
```

### Weekly Test Restore (Automated)
```bash
# Runs automatically every Sunday at 05:00
/opt/planetplant/scripts/test-restore-procedure.sh weekly
```

### Monthly Full Recovery Test
```bash
# Manual execution required - simulate complete failure
/opt/planetplant/scripts/disaster-recovery-test.sh monthly
```

## 🌍 Alternative Deployment Options

### Cloud Emergency Deployment
**Purpose:** Temporary deployment when on-premises is unavailable

#### AWS Deployment
```bash
cd deployment/cloud/aws
terraform init
terraform apply -var="instance_type=t3.medium"

# Restore from S3 backups
./restore-from-s3.sh
```

#### DigitalOcean Deployment  
```bash
cd deployment/cloud/digitalocean
terraform init
terraform apply -var="droplet_size=s-2vcpu-4gb"

# Restore from cloud backups
./restore-from-spaces.sh
```

### DNS Failover Configuration
**Primary DNS:** Pi-IP-Address
**Backup DNS:** Cloud-Instance-IP

```bash
# Update DNS programmatically
./scripts/update-dns-failover.sh cloud
./scripts/update-dns-failover.sh onprem
```

## 🚨 Incident Response Playbooks

### Playbook 1: Service Down Alert
**Trigger:** Uptime Kuma detects service down > 2 minutes

1. **Immediate Response (0-5 min):**
   ```bash
   # Check service status
   docker ps | grep planetplant
   curl http://localhost:3001/api/health
   
   # Quick restart
   docker compose restart [failed-service]
   ```

2. **If restart fails (5-15 min):**
   ```bash
   # Check logs for errors
   docker compose logs [failed-service] --tail=100
   
   # Check system resources
   docker stats --no-stream
   free -h
   df -h
   
   # Force recreate if needed
   docker compose up -d --force-recreate [failed-service]
   ```

3. **If problem persists (15+ min):**
   ```bash
   # Execute emergency restore
   sudo /opt/planetplant/scripts/emergency-restore.sh
   
   # Escalate to Level 2
   ```

### Playbook 2: High Resource Usage Alert
**Trigger:** CPU > 80% or Memory > 80% for 10+ minutes

1. **Investigate resource usage:**
   ```bash
   # Check container resources
   docker stats --no-stream
   
   # Check system processes
   htop
   
   # Check disk space
   df -h
   du -sh /opt/planetplant/data/*
   ```

2. **Immediate mitigation:**
   ```bash
   # Clean up logs
   find /opt/planetplant/logs -name "*.log" -mtime +7 -delete
   
   # Clean up old containers
   docker system prune -f
   
   # Restart heavy services
   docker compose restart backend grafana
   ```

3. **Long-term solution:**
   ```bash
   # Check for memory leaks
   docker compose logs backend | grep -i memory
   
   # Consider scaling or resource limit adjustments
   nano docker-compose.yml  # Update resource limits
   ```

### Playbook 3: No Sensor Data Alert
**Trigger:** No sensor readings for 15+ minutes

1. **Check MQTT connectivity:**
   ```bash
   # Test MQTT broker
   docker exec planetplant-mosquitto mosquitto_pub -t test -m "connectivity test"
   
   # Check ESP32 devices
   # Physical inspection required
   ```

2. **Check backend processing:**
   ```bash
   # Check MQTT client status
   curl http://localhost:3001/api/health | jq '.services.mqtt'
   
   # Check recent sensor data
   curl http://localhost:3001/api/plants | jq '.data[].lastSeen'
   ```

3. **ESP32 troubleshooting:**
   ```bash
   # Check WiFi connectivity
   # Check power supply
   # Check sensor connections
   # Restart ESP32 devices
   ```

## 📱 Emergency Response Checklist

### When You Get an Alert

- [ ] **Acknowledge alert** in monitoring system
- [ ] **Check system status** via status page
- [ ] **Identify affected services** 
- [ ] **Check logs** for immediate error clues
- [ ] **Attempt quick fix** (restart, clear disk space)
- [ ] **Escalate if needed** (> 15 minutes)
- [ ] **Document actions taken**
- [ ] **Verify recovery** after fix
- [ ] **Update procedures** if needed

### Critical System Files Backup Locations

```bash
# Configuration backup
/opt/planetplant/backups/emergency/current-config.tar.gz

# Database backup (daily)
/opt/planetplant/backups/restic-repo/latest/influxdb/

# Full system backup (weekly) 
/opt/planetplant/backups/restic-repo/snapshots/

# Cloud backup locations
s3://planetplant-backups/[hostname]/
drive://PlanetPlant-Backups/[hostname]/
```

## 🔄 Business Continuity

### Service Dependencies
```
Frontend ──→ Nginx ──→ Backend ──→ InfluxDB
                    ├──→ MQTT ──→ ESP32 Devices  
                    └──→ Redis
```

### Minimum Viable System
For emergency operations, the following services are sufficient:
- **Backend API** (core functionality)
- **InfluxDB** (data storage)
- **MQTT Broker** (device communication)

Optional services that can be disabled temporarily:
- Grafana (monitoring dashboards)
- Redis (caching - degrades performance only)
- Frontend (API still accessible)

### Alternative Access Methods
If web interface is down:
- **Direct API:** `curl http://[PI-IP]:3001/api/plants`
- **MQTT Commands:** Direct device control via MQTT
- **InfluxDB Console:** Direct database queries
- **SSH Access:** Full system control

## 📞 Escalation Procedures

### Level 1 Response (On-Call Engineer)
**Response Time:** 0-15 minutes
**Scope:** Basic service restarts, log checking

**Actions:**
- Check monitoring dashboards
- Attempt service restarts
- Basic log analysis
- System resource check

**Escalation Criteria:**
- Service restart doesn't resolve issue
- Resource constraints identified
- Database integrity concerns
- Hardware-related symptoms

### Level 2 Response (DevOps Engineer)
**Response Time:** 15-30 minutes  
**Scope:** Advanced troubleshooting, backup restores

**Actions:**
- Advanced log analysis
- Backup restoration procedures
- System configuration changes
- Performance optimization

**Escalation Criteria:**
- Hardware failure suspected
- Data loss identified
- Security incident
- Multiple system failures

### Level 3 Response (Technical Lead)
**Response Time:** 30-60 minutes
**Scope:** Architecture decisions, vendor coordination

**Actions:**
- Hardware replacement decisions
- Cloud failover authorization
- Vendor coordination
- Architecture modifications

### Level 4 Response (External Support)
**Response Time:** 1-4 hours
**Scope:** Vendor support, specialized recovery

**Vendors:**
- Hardware replacement
- Network/ISP issues
- Cloud provider support
- Security incident response

## 💾 Hardware Replacement Procedures

### Raspberry Pi Replacement
**Required Parts:**
- Raspberry Pi 5 (8GB) or Pi 4 (4GB minimum)
- 64GB+ SD Card (Class 10, A2 rating)
- Power Supply (5V/5A for Pi 5)
- Ethernet cable or WiFi access

**Quick Replacement Steps:**
1. **Flash new SD card** with Raspberry Pi OS
2. **Enable SSH** and configure network
3. **Run migration script:**
   ```bash
   curl -sSL https://raw.githubusercontent.com/PhilKsr/planetplant/main/scripts/emergency-setup.sh | bash
   ```
4. **Restore from backup:**
   ```bash
   sudo /opt/planetplant/scripts/migrate-to-new-pi.sh
   ```

### Network Equipment
- **Router failure:** Use mobile hotspot as temporary solution
- **Switch failure:** Direct connect to router
- **ISP outage:** Enable cloud failover mode

### Storage Failure
```bash
# Emergency data export before failure
/opt/planetplant/scripts/export-all-data.sh /backup-location/

# Mount external storage
sudo mount /dev/sda1 /mnt/emergency-storage

# Redirect data directory temporarily  
docker compose down
sudo mv /opt/planetplant/data /mnt/emergency-storage/
sudo ln -s /mnt/emergency-storage/data /opt/planetplant/data
docker compose up -d
```

## 🔒 Security Incident Response

### Data Breach Response
1. **Immediate isolation** - Disconnect from network
2. **Assess impact** - What data was accessed?
3. **Preserve evidence** - Don't modify system
4. **Notify stakeholders** - Follow legal requirements
5. **Forensic analysis** - Work with security experts
6. **System hardening** - Fix vulnerabilities
7. **Monitor for reoccurrence**

### Unauthorized Access
```bash
# Check access logs
docker compose logs nginx | grep "POST\|PUT\|DELETE"

# Check authentication failures
docker compose logs backend | grep "authentication failed"

# Review system logs
journalctl -u ssh --since "1 hour ago"

# Change all passwords if needed
./scripts/rotate-all-passwords.sh
```

## 🧪 Recovery Testing Schedule

### Monthly Tests
- **Backup restoration test** (automated)
- **Service failover test**
- **Monitoring alert test**
- **Documentation review**

### Quarterly Tests
- **Full disaster recovery simulation**
- **Hardware replacement drill**
- **Cloud failover test**
- **Contact list verification**

### Annual Tests
- **Complete building evacuation scenario**
- **Vendor response time verification**
- **Insurance claim process review**
- **Full DR plan update**

## 📋 Post-Incident Procedures

### Incident Documentation
**Required Information:**
- Incident start time and detection method
- Root cause analysis
- Actions taken and results
- Recovery time achieved
- Data loss assessment
- Lessons learned
- Procedure improvements

### Recovery Verification Checklist
- [ ] All services responding to health checks
- [ ] Frontend accessible and functional
- [ ] Backend API endpoints working
- [ ] Database queries returning data
- [ ] MQTT devices connecting and sending data
- [ ] Monitoring systems operational
- [ ] Backup systems functional
- [ ] All alerts cleared

### Follow-up Actions
- [ ] Update monitoring if new failure modes discovered
- [ ] Enhance recovery scripts based on experience
- [ ] Training for team members
- [ ] Review and update contact information
- [ ] Hardware/software updates to prevent recurrence

## 📞 Emergency Communication Plan

### Internal Communication
- **Slack:** #planetplant-incidents (real-time updates)
- **Email:** incidents@planetplant.local (formal notifications)
- **Phone:** For critical incidents requiring immediate attention

### External Communication
- **Users:** Status page updates (http://status.planetplant.local)
- **Stakeholders:** Email notifications with ETA
- **Vendors:** Direct contact for hardware/service issues

### Communication Templates

#### Service Disruption Notice
```
Subject: [PlanetPlant] Service Disruption - [Service Name]

We are experiencing issues with [service name] as of [time].

Impact: [Description of user impact]
Estimated Resolution: [ETA]
Workaround: [If available]

We will provide updates every 30 minutes until resolved.

Technical Team
```

#### Service Restored Notice
```
Subject: [PlanetPlant] Service Restored - [Service Name]

Service [service name] has been fully restored as of [time].

Root Cause: [Brief explanation]
Resolution: [What was done]
Prevention: [What we're doing to prevent recurrence]

Total downtime: [Duration]

Thank you for your patience.
```

## 🎯 Continuous Improvement

### Recovery Metrics Tracking
- **Mean Time To Recovery (MTTR)**
- **Recovery Time Objective achievement**
- **False positive alert rate**
- **Backup success rate**
- **Test restore success rate**

### Monthly Review Process
1. **Incident analysis** - What happened this month?
2. **Recovery time analysis** - Are we meeting RTO?
3. **Backup verification** - Are backups working?
4. **Contact list updates** - Any changes needed?
5. **Procedure updates** - What can be improved?

### Quarterly DR Planning
- **Technology updates** - New tools or methods
- **Team training** - Hands-on recovery practice
- **Vendor reviews** - Are current vendors meeting SLAs?
- **Hardware refresh** - Plan for equipment updates

---

## 🚀 Quick Reference Card

### Emergency Commands
```bash
# System status
make health

# Quick restart
make restart

# Emergency backup  
make backup-emergency

# Latest restore
sudo make restore-latest

# Service logs
make logs

# Resource check
make status
```

### Emergency Contacts
- **On-Call:** [Phone number]
- **Technical Lead:** [Phone number]  
- **Vendor Support:** [Phone number]

### Critical URLs
- **Status:** http://localhost:3005/status
- **Health:** http://localhost:3001/api/health
- **Management:** http://localhost:9000

**Remember:** Document everything, stay calm, follow procedures! 🌱
terraform {
  required_version = ">= 1.5"
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.34"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

provider "digitalocean" {
  token = var.do_token
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

# SSH Key
resource "digitalocean_ssh_key" "planetplant_key" {
  name       = "planetplant-${var.environment}"
  public_key = var.public_key
}

# Droplet
resource "digitalocean_droplet" "planetplant" {
  image              = "ubuntu-22-04-x64"
  name               = "planetplant-${var.environment}"
  region             = var.do_region
  size               = var.droplet_size
  monitoring         = true
  ipv6               = true
  ssh_keys           = [digitalocean_ssh_key.planetplant_key.fingerprint]
  resize_disk        = true
  backup_retention_policy_enabled = true

  user_data = templatefile("${path.module}/user-data.sh", {
    domain_name           = var.domain_name
    influxdb_password     = var.influxdb_password
    influxdb_token        = var.influxdb_token
    redis_password        = var.redis_password
    jwt_secret            = var.jwt_secret
    grafana_password      = var.grafana_password
    spaces_key            = digitalocean_spaces_bucket.backup_bucket.access_id
    spaces_secret         = digitalocean_spaces_bucket.backup_bucket.secret_key
    spaces_endpoint       = digitalocean_spaces_bucket.backup_bucket.endpoint
    spaces_bucket         = digitalocean_spaces_bucket.backup_bucket.name
    do_region             = var.do_region
    slack_webhook         = var.slack_webhook
    cloudflare_zone_id    = var.cloudflare_zone_id
    cloudflare_api_token  = var.cloudflare_api_token
  })

  tags = [
    "planetplant",
    var.environment,
    "web",
    "iot"
  ]
}

# Spaces bucket for backups
resource "digitalocean_spaces_bucket" "backup_bucket" {
  name   = "${var.project_name}-backups-${var.environment}"
  region = var.do_region
  acl    = "private"

  versioning {
    enabled = true
  }

  lifecycle_rule {
    id      = "delete_old_backups"
    enabled = true

    expiration {
      days = var.backup_retention_days
    }

    noncurrent_version_expiration {
      days = 7
    }
  }
}

# Firewall
resource "digitalocean_firewall" "planetplant_fw" {
  name = "planetplant-firewall-${var.environment}"

  droplet_ids = [digitalocean_droplet.planetplant.id]

  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = var.allowed_ssh_cidrs
  }

  inbound_rule {
    protocol         = "tcp"
    port_range       = "80"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  inbound_rule {
    protocol         = "tcp"
    port_range       = "443"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  inbound_rule {
    protocol         = "tcp"
    port_range       = "1883"
    source_addresses = var.mqtt_allowed_cidrs
  }

  inbound_rule {
    protocol         = "tcp"
    port_range       = "9001"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "tcp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "udp"
    port_range            = "53"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "icmp"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}

# Load Balancer
resource "digitalocean_loadbalancer" "planetplant_lb" {
  name                     = "planetplant-lb-${var.environment}"
  type                     = "lb"
  algorithm                = "round_robin"
  region                   = var.do_region
  size_unit                = 1
  enable_proxy_protocol    = false
  enable_backend_keepalive = true
  
  forwarding_rule {
    entry_protocol  = "http"
    entry_port      = 80
    target_protocol = "http"
    target_port     = 80
  }

  forwarding_rule {
    entry_protocol   = "https"
    entry_port       = 443
    target_protocol  = "http"
    target_port      = 80
    certificate_name = var.ssl_certificate_name
  }

  healthcheck {
    protocol               = "http"
    port                   = 80
    path                   = "/health"
    check_interval_seconds = 30
    response_timeout_seconds = 10
    unhealthy_threshold    = 3
    healthy_threshold      = 2
  }

  droplet_ids = [digitalocean_droplet.planetplant.id]

  redirect_http_to_https = true
}

# Reserved IP
resource "digitalocean_reserved_ip" "planetplant_ip" {
  type   = "assign"
  droplet = digitalocean_droplet.planetplant.id
  region = var.do_region
}

# Volume for persistent data (optional)
resource "digitalocean_volume" "planetplant_data" {
  count                   = var.enable_separate_volume ? 1 : 0
  region                  = var.do_region
  name                    = "planetplant-data-${var.environment}"
  size                    = var.data_volume_size
  initial_filesystem_type = "ext4"
  description             = "PlanetPlant persistent data volume"

  tags = [
    "planetplant",
    var.environment,
    "data"
  ]
}

resource "digitalocean_volume_attachment" "planetplant_data_attachment" {
  count      = var.enable_separate_volume ? 1 : 0
  droplet_id = digitalocean_droplet.planetplant.id
  volume_id  = digitalocean_volume.planetplant_data[0].id
}

# Monitoring alerts
resource "digitalocean_monitor_alert" "cpu_alert" {
  alerts {
    email = var.alert_email != "" ? [var.alert_email] : []
    slack {
      channel = "#planetplant-alerts"
      url     = var.slack_webhook
    }
  }
  
  window      = "5m"
  type        = "v1/insights/droplet/cpu"
  compare     = "GreaterThan"
  value       = 80
  enabled     = true
  entities    = [digitalocean_droplet.planetplant.id]
  description = "PlanetPlant high CPU usage"

  tags = [
    "planetplant",
    var.environment
  ]
}

resource "digitalocean_monitor_alert" "memory_alert" {
  alerts {
    email = var.alert_email != "" ? [var.alert_email] : []
    slack {
      channel = "#planetplant-alerts"
      url     = var.slack_webhook
    }
  }
  
  window      = "5m"
  type        = "v1/insights/droplet/memory_utilization_percent"
  compare     = "GreaterThan"
  value       = 85
  enabled     = true
  entities    = [digitalocean_droplet.planetplant.id]
  description = "PlanetPlant high memory usage"

  tags = [
    "planetplant",
    var.environment
  ]
}

# Database cluster (optional for production)
resource "digitalocean_database_cluster" "planetplant_db" {
  count      = var.use_managed_database ? 1 : 0
  name       = "planetplant-db-${var.environment}"
  engine     = "redis"
  version    = "7"
  size       = "db-s-1vcpu-1gb"
  region     = var.do_region
  node_count = 1

  tags = [
    "planetplant",
    var.environment,
    "database"
  ]
}

# Container Registry
resource "digitalocean_container_registry" "planetplant_registry" {
  count                     = var.create_registry ? 1 : 0
  name                      = "planetplant-${var.environment}"
  subscription_tier_slug    = var.registry_tier
  region                    = var.do_region
}

# App Platform (alternative deployment method)
resource "digitalocean_app" "planetplant_app" {
  count = var.use_app_platform ? 1 : 0

  spec {
    name   = "planetplant-${var.environment}"
    region = var.do_region

    # Frontend service
    service {
      name               = "frontend"
      environment_slug   = "node-js"
      instance_count     = 1
      instance_size_slug = "basic-xxs"

      github {
        repo           = var.github_repo
        branch         = var.environment == "production" ? "main" : "develop"
        deploy_on_push = true
      }

      source_dir = "/webapp"
      
      env {
        key   = "REACT_APP_API_URL"
        value = "https://api.${var.domain_name}"
      }

      env {
        key   = "REACT_APP_WS_URL"
        value = "wss://api.${var.domain_name}"
      }

      routes {
        path = "/"
      }

      health_check {
        http_path = "/health"
      }
    }

    # Backend service
    service {
      name               = "backend"
      environment_slug   = "node-js"
      instance_count     = 1
      instance_size_slug = "basic-xs"

      github {
        repo           = var.github_repo
        branch         = var.environment == "production" ? "main" : "develop"
        deploy_on_push = true
      }

      source_dir = "/raspberry-pi"

      env {
        key   = "NODE_ENV"
        value = "production"
      }

      env {
        key   = "PORT"
        value = "3001"
      }

      env {
        key   = "REDIS_URL"
        value = var.use_managed_database ? digitalocean_database_cluster.planetplant_db[0].uri : "redis://redis:6379"
      }

      routes {
        path = "/api"
      }

      health_check {
        http_path = "/api/health"
      }
    }

    # InfluxDB service (containerized)
    service {
      name               = "influxdb"
      environment_slug   = "docker"
      instance_count     = 1
      instance_size_slug = "basic-s"

      image {
        registry_type = "DOCKER_HUB"
        repository    = "influxdb"
        tag          = "2.7-alpine"
      }

      env {
        key   = "DOCKER_INFLUXDB_INIT_MODE"
        value = "setup"
      }

      env {
        key   = "DOCKER_INFLUXDB_INIT_USERNAME"
        value = "admin"
      }

      env {
        key   = "DOCKER_INFLUXDB_INIT_PASSWORD"
        value = var.influxdb_password
        type  = "SECRET"
      }

      env {
        key   = "DOCKER_INFLUXDB_INIT_ORG"
        value = "planetplant"
      }

      env {
        key   = "DOCKER_INFLUXDB_INIT_BUCKET"
        value = "sensor-data"
      }

      env {
        key   = "DOCKER_INFLUXDB_INIT_ADMIN_TOKEN"
        value = var.influxdb_token
        type  = "SECRET"
      }

      health_check {
        http_path = "/ping"
        port      = 8086
      }
    }

    domain {
      name = var.domain_name
      type = "PRIMARY"
    }
  }
}

# Cloudflare DNS Records
resource "cloudflare_record" "planetplant_a" {
  zone_id = var.cloudflare_zone_id
  name    = var.environment == "production" ? "@" : var.environment
  value   = var.use_app_platform ? digitalocean_app.planetplant_app[0].live_url : digitalocean_reserved_ip.planetplant_ip.ip_address
  type    = var.use_app_platform ? "CNAME" : "A"
  ttl     = 300

  lifecycle {
    create_before_destroy = true
  }
}

resource "cloudflare_record" "planetplant_api" {
  zone_id = var.cloudflare_zone_id
  name    = var.environment == "production" ? "api" : "api-${var.environment}"
  value   = var.use_app_platform ? digitalocean_app.planetplant_app[0].live_url : digitalocean_reserved_ip.planetplant_ip.ip_address
  type    = var.use_app_platform ? "CNAME" : "A"
  ttl     = 300
}

# Uptime monitoring
resource "digitalocean_uptime_check" "planetplant_frontend" {
  name    = "planetplant-frontend-${var.environment}"
  target  = "https://${var.domain_name}"
  type    = "https"
  regions = ["us_east", "eu_central"]
  enabled = true
}

resource "digitalocean_uptime_check" "planetplant_api" {
  name    = "planetplant-api-${var.environment}"
  target  = "https://api.${var.domain_name}/api/health"
  type    = "https"
  regions = ["us_east", "eu_central"]
  enabled = true
}
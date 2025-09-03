terraform {
  required_version = ">= 1.5"
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

# Health check for primary site (Raspberry Pi)
resource "cloudflare_healthcheck" "primary_health" {
  zone_id              = var.cloudflare_zone_id
  name                 = "planetplant-primary-${var.environment}"
  address              = var.primary_ip
  type                 = "HTTPS"
  path                 = "/api/health"
  port                 = 443
  method               = "GET"
  timeout              = 10
  retries              = 3
  interval             = 60
  consecutive_fails    = 3
  consecutive_successes = 2
  description          = "Health check for primary PlanetPlant instance (Raspberry Pi)"

  header = {
    "Host" = var.primary_domain
  }

  check_regions = [
    "WEU",  # Western Europe
    "ENAM", # Eastern North America
    "WAS"   # Western Asia
  ]
}

# Health check for secondary site (Cloud)
resource "cloudflare_healthcheck" "secondary_health" {
  zone_id              = var.cloudflare_zone_id
  name                 = "planetplant-secondary-${var.environment}"
  address              = var.secondary_ip
  type                 = "HTTPS"
  path                 = "/api/health"
  port                 = 443
  method               = "GET"
  timeout              = 10
  retries              = 3
  interval             = 60
  consecutive_fails    = 3
  consecutive_successes = 2
  description          = "Health check for secondary PlanetPlant instance (Cloud)"

  header = {
    "Host" = var.secondary_domain
  }

  check_regions = [
    "WEU",  # Western Europe
    "ENAM", # Eastern North America
    "WAS"   # Western Asia
  ]
}

# Load balancer pool
resource "cloudflare_load_balancer_pool" "primary_pool" {
  name = "planetplant-primary-${var.environment}"
  
  origins {
    name    = "primary-pi"
    address = var.primary_ip
    enabled = true
    weight  = 1
    header = {
      "Host" = var.primary_domain
    }
  }

  description            = "Primary PlanetPlant pool (Raspberry Pi)"
  enabled                = true
  minimum_origins        = 1
  monitor               = cloudflare_healthcheck.primary_health.id
  notification_email     = var.notification_email
  
  check_regions = [
    "WEU",  # Western Europe
    "ENAM"  # Eastern North America
  ]

  load_shedding {
    default_percent = 0
    default_policy  = "random"
    session_percent = 0
    session_policy  = "hash"
  }
}

resource "cloudflare_load_balancer_pool" "secondary_pool" {
  name = "planetplant-secondary-${var.environment}"
  
  origins {
    name    = "secondary-cloud"
    address = var.secondary_ip
    enabled = true
    weight  = 1
    header = {
      "Host" = var.secondary_domain
    }
  }

  description            = "Secondary PlanetPlant pool (Cloud)"
  enabled                = true
  minimum_origins        = 1
  monitor               = cloudflare_healthcheck.secondary_health.id
  notification_email     = var.notification_email
  
  check_regions = [
    "WEU",  # Western Europe
    "ENAM"  # Eastern North America
  ]

  load_shedding {
    default_percent = 0
    default_policy  = "random"
    session_percent = 0
    session_policy  = "hash"
  }
}

# Load balancer for main domain
resource "cloudflare_load_balancer" "planetplant_lb" {
  zone_id          = var.cloudflare_zone_id
  name             = var.environment == "production" ? var.domain_name : "${var.environment}.${var.domain_name}"
  fallback_pool_id = cloudflare_load_balancer_pool.secondary_pool.id
  default_pool_ids = [cloudflare_load_balancer_pool.primary_pool.id]
  description      = "PlanetPlant load balancer with failover"
  ttl              = 30
  steering_policy  = "off"
  proxied          = true
  enabled          = true

  # Failover rules
  rules {
    name      = "failover-to-cloud"
    condition = "http.request.uri.path contains \"/\""
    
    overrides {
      default_pools    = [cloudflare_load_balancer_pool.secondary_pool.id]
      fallback_pool    = cloudflare_load_balancer_pool.secondary_pool.id
      steering_policy  = "off"
      ttl             = 30
    }
  }

  # Geographic routing (optional)
  region_pools = {
    "WEUR" = [cloudflare_load_balancer_pool.primary_pool.id, cloudflare_load_balancer_pool.secondary_pool.id]
    "ENAM" = [cloudflare_load_balancer_pool.secondary_pool.id, cloudflare_load_balancer_pool.primary_pool.id]
  }

  pop_pools = {
    "LAX" = [cloudflare_load_balancer_pool.secondary_pool.id]
    "LHR" = [cloudflare_load_balancer_pool.primary_pool.id]
  }
}

# API subdomain load balancer
resource "cloudflare_load_balancer" "planetplant_api_lb" {
  zone_id          = var.cloudflare_zone_id
  name             = var.environment == "production" ? "api.${var.domain_name}" : "api-${var.environment}.${var.domain_name}"
  fallback_pool_id = cloudflare_load_balancer_pool.secondary_pool.id
  default_pool_ids = [cloudflare_load_balancer_pool.primary_pool.id]
  description      = "PlanetPlant API load balancer with failover"
  ttl              = 30
  steering_policy  = "off"
  proxied          = true
  enabled          = true

  # API-specific failover rules
  rules {
    name      = "api-failover"
    condition = "http.request.uri.path matches \"^/api/.*\""
    
    overrides {
      default_pools    = [cloudflare_load_balancer_pool.secondary_pool.id]
      fallback_pool    = cloudflare_load_balancer_pool.secondary_pool.id
      steering_policy  = "off"
      ttl             = 30
    }
  }
}

# Page rules for caching and security
resource "cloudflare_page_rule" "api_cache_bypass" {
  zone_id  = var.cloudflare_zone_id
  target   = var.environment == "production" ? "api.${var.domain_name}/api/*" : "api-${var.environment}.${var.domain_name}/api/*"
  priority = 1

  actions {
    cache_level = "bypass"
    ssl         = "strict"
  }
}

resource "cloudflare_page_rule" "static_cache" {
  zone_id  = var.cloudflare_zone_id
  target   = var.environment == "production" ? "${var.domain_name}/static/*" : "${var.environment}.${var.domain_name}/static/*"
  priority = 2

  actions {
    cache_level    = "cache_everything"
    edge_cache_ttl = 86400  # 24 hours
    browser_cache_ttl = 3600   # 1 hour
  }
}

# Rate limiting for API endpoints
resource "cloudflare_rate_limit" "api_rate_limit" {
  zone_id   = var.cloudflare_zone_id
  threshold = var.api_rate_limit_threshold
  period    = 60
  match {
    request {
      url_pattern = var.environment == "production" ? "api.${var.domain_name}/api/*" : "api-${var.environment}.${var.domain_name}/api/*"
      schemes     = ["HTTPS"]
      methods     = ["GET", "POST", "PUT", "DELETE"]
    }
  }
  
  action {
    mode    = "simulate"  # Change to "ban" for production
    timeout = 86400
    response {
      content_type = "application/json"
      body         = "{\"error\":\"Rate limit exceeded\"}"
    }
  }

  correlate {
    by = "ip"
  }

  disabled = false
  description = "Rate limiting for PlanetPlant API"
}

# WAF rules for basic security
resource "cloudflare_filter" "block_bad_bots" {
  zone_id     = var.cloudflare_zone_id
  description = "Block known bad bots"
  expression  = "(cf.client.bot) or (http.user_agent contains \"bot\" and not http.user_agent contains \"Googlebot\")"
}

resource "cloudflare_firewall_rule" "block_bad_bots_rule" {
  zone_id     = var.cloudflare_zone_id
  description = "Block bad bots firewall rule"
  filter_id   = cloudflare_filter.block_bad_bots.id
  action      = "block"
  priority    = 1
}

# DNS record for monitoring endpoint
resource "cloudflare_record" "monitoring" {
  zone_id = var.cloudflare_zone_id
  name    = var.environment == "production" ? "status" : "status-${var.environment}"
  value   = var.primary_ip
  type    = "A"
  ttl     = 60
  comment = "Direct access to primary instance for monitoring"
}
variable "environment" {
  description = "Environment name (development, staging, production)"
  type        = string
  default     = "production"
}

variable "domain_name" {
  description = "Primary domain name"
  type        = string
}

variable "primary_ip" {
  description = "IP address of primary instance (Raspberry Pi)"
  type        = string
}

variable "secondary_ip" {
  description = "IP address of secondary instance (Cloud)"
  type        = string
}

variable "primary_domain" {
  description = "Primary domain for health checks"
  type        = string
}

variable "secondary_domain" {
  description = "Secondary domain for health checks"
  type        = string
}

variable "cloudflare_zone_id" {
  description = "Cloudflare zone ID for DNS management"
  type        = string
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token"
  type        = string
  sensitive   = true
}

variable "notification_email" {
  description = "Email for health check notifications"
  type        = string
}

variable "api_rate_limit_threshold" {
  description = "API rate limit threshold per minute"
  type        = number
  default     = 100
}

variable "enable_waf" {
  description = "Whether to enable WAF rules"
  type        = bool
  default     = true
}

variable "health_check_regions" {
  description = "Cloudflare regions for health checks"
  type        = list(string)
  default     = ["WEU", "ENAM", "WAS"]
}
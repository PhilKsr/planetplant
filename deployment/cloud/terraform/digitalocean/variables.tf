variable "do_token" {
  description = "DigitalOcean API token"
  type        = string
  sensitive   = true
}

variable "do_region" {
  description = "DigitalOcean region"
  type        = string
  default     = "fra1"
}

variable "environment" {
  description = "Environment name (development, staging, production)"
  type        = string
  default     = "production"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "planetplant"
}

variable "domain_name" {
  description = "Domain name for the application"
  type        = string
}

variable "droplet_size" {
  description = "DigitalOcean droplet size"
  type        = string
  default     = "s-2vcpu-4gb"
}

variable "public_key" {
  description = "Public SSH key for droplet access"
  type        = string
}

variable "allowed_ssh_cidrs" {
  description = "CIDR blocks allowed for SSH access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "mqtt_allowed_cidrs" {
  description = "CIDR blocks allowed for MQTT access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "backup_retention_days" {
  description = "Number of days to retain backups"
  type        = number
  default     = 30
}

variable "alert_email" {
  description = "Email for monitoring alerts"
  type        = string
  default     = ""
}

variable "enable_separate_volume" {
  description = "Whether to create a separate volume for data"
  type        = bool
  default     = false
}

variable "data_volume_size" {
  description = "Size of the data volume in GB"
  type        = number
  default     = 50
}

variable "use_managed_database" {
  description = "Whether to use DigitalOcean managed Redis"
  type        = bool
  default     = false
}

variable "create_registry" {
  description = "Whether to create a container registry"
  type        = bool
  default     = false
}

variable "registry_tier" {
  description = "Container registry tier"
  type        = string
  default     = "starter"
}

variable "use_app_platform" {
  description = "Whether to use DigitalOcean App Platform instead of droplets"
  type        = bool
  default     = false
}

variable "github_repo" {
  description = "GitHub repository for App Platform deployment"
  type        = string
  default     = ""
}

# Environment variables for application
variable "influxdb_password" {
  description = "InfluxDB admin password"
  type        = string
  sensitive   = true
}

variable "influxdb_token" {
  description = "InfluxDB authentication token"
  type        = string
  sensitive   = true
}

variable "redis_password" {
  description = "Redis password"
  type        = string
  sensitive   = true
}

variable "jwt_secret" {
  description = "JWT secret for authentication"
  type        = string
  sensitive   = true
}

variable "grafana_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
}

variable "slack_webhook" {
  description = "Slack webhook URL for notifications"
  type        = string
  default     = ""
  sensitive   = true
}

# Cloudflare configuration
variable "cloudflare_zone_id" {
  description = "Cloudflare zone ID for DNS management"
  type        = string
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token"
  type        = string
  sensitive   = true
}

variable "ssl_certificate_name" {
  description = "Name of the SSL certificate in DigitalOcean"
  type        = string
  default     = ""
}
output "primary_pool_id" {
  description = "ID of the primary load balancer pool"
  value       = cloudflare_load_balancer_pool.primary_pool.id
}

output "secondary_pool_id" {
  description = "ID of the secondary load balancer pool"
  value       = cloudflare_load_balancer_pool.secondary_pool.id
}

output "main_load_balancer_id" {
  description = "ID of the main load balancer"
  value       = cloudflare_load_balancer.planetplant_lb.id
}

output "api_load_balancer_id" {
  description = "ID of the API load balancer"
  value       = cloudflare_load_balancer.planetplant_api_lb.id
}

output "primary_health_check_id" {
  description = "ID of the primary health check"
  value       = cloudflare_healthcheck.primary_health.id
}

output "secondary_health_check_id" {
  description = "ID of the secondary health check"
  value       = cloudflare_healthcheck.secondary_health.id
}

output "primary_pool_status" {
  description = "Status URL for primary pool monitoring"
  value       = "https://dash.cloudflare.com/api/v4/zones/${var.cloudflare_zone_id}/load_balancers/pools/${cloudflare_load_balancer_pool.primary_pool.id}/health"
}

output "secondary_pool_status" {
  description = "Status URL for secondary pool monitoring"
  value       = "https://dash.cloudflare.com/api/v4/zones/${var.cloudflare_zone_id}/load_balancers/pools/${cloudflare_load_balancer_pool.secondary_pool.id}/health"
}

output "load_balancer_dns" {
  description = "DNS name for the load-balanced domain"
  value       = var.environment == "production" ? var.domain_name : "${var.environment}.${var.domain_name}"
}

output "api_dns" {
  description = "DNS name for the API load-balanced domain"
  value       = var.environment == "production" ? "api.${var.domain_name}" : "api-${var.environment}.${var.domain_name}"
}

output "monitoring_url" {
  description = "Direct monitoring URL (bypasses load balancer)"
  value       = var.environment == "production" ? "https://status.${var.domain_name}" : "https://status-${var.environment}.${var.domain_name}"
}
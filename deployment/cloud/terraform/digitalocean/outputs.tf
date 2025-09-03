output "droplet_id" {
  description = "ID of the DigitalOcean droplet"
  value       = digitalocean_droplet.planetplant.id
}

output "droplet_ip" {
  description = "Public IP address of the droplet"
  value       = digitalocean_droplet.planetplant.ipv4_address
}

output "reserved_ip" {
  description = "Reserved IP address"
  value       = digitalocean_reserved_ip.planetplant_ip.ip_address
}

output "loadbalancer_ip" {
  description = "Load balancer IP address"
  value       = digitalocean_loadbalancer.planetplant_lb.ip
}

output "spaces_bucket_name" {
  description = "Name of the Spaces backup bucket"
  value       = digitalocean_spaces_bucket.backup_bucket.name
}

output "spaces_bucket_endpoint" {
  description = "Endpoint of the Spaces backup bucket"
  value       = digitalocean_spaces_bucket.backup_bucket.endpoint
}

output "volume_id" {
  description = "ID of the data volume (if created)"
  value       = var.enable_separate_volume ? digitalocean_volume.planetplant_data[0].id : null
}

output "firewall_id" {
  description = "ID of the firewall"
  value       = digitalocean_firewall.planetplant_fw.id
}

output "app_platform_url" {
  description = "App Platform live URL (if used)"
  value       = var.use_app_platform ? digitalocean_app.planetplant_app[0].live_url : null
}

output "domain_url" {
  description = "Full domain URL for the application"
  value       = var.environment == "production" ? "https://${var.domain_name}" : "https://${var.environment}.${var.domain_name}"
}

output "api_url" {
  description = "API endpoint URL"
  value       = var.environment == "production" ? "https://api.${var.domain_name}" : "https://api-${var.environment}.${var.domain_name}"
}

output "ssh_command" {
  description = "SSH command to connect to the droplet"
  value       = "ssh root@${digitalocean_reserved_ip.planetplant_ip.ip_address}"
}
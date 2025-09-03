output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.planetplant_vpc.id
}

output "public_subnet_id" {
  description = "ID of the public subnet"
  value       = aws_subnet.public_subnet.id
}

output "security_group_id" {
  description = "ID of the security group"
  value       = aws_security_group.planetplant_sg.id
}

output "load_balancer_dns" {
  description = "DNS name of the load balancer"
  value       = aws_lb.planetplant_alb.dns_name
}

output "load_balancer_arn" {
  description = "ARN of the load balancer"
  value       = aws_lb.planetplant_alb.arn
}

output "backup_bucket_name" {
  description = "Name of the S3 backup bucket"
  value       = aws_s3_bucket.backup_bucket.bucket
}

output "backup_bucket_arn" {
  description = "ARN of the S3 backup bucket"
  value       = aws_s3_bucket.backup_bucket.arn
}

output "cloudwatch_log_group" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.planetplant_logs.name
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for alerts"
  value       = aws_sns_topic.alerts.arn
}

output "instance_profile_arn" {
  description = "ARN of the IAM instance profile"
  value       = aws_iam_instance_profile.planetplant_profile.arn
}

output "domain_url" {
  description = "Full domain URL for the application"
  value       = var.environment == "production" ? "https://${var.domain_name}" : "https://${var.environment}.${var.domain_name}"
}

output "api_url" {
  description = "API endpoint URL"
  value       = var.environment == "production" ? "https://api.${var.domain_name}" : "https://api-${var.environment}.${var.domain_name}"
}
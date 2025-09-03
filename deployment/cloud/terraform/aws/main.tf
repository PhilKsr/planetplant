terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-22.04-lts-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# VPC and Networking
resource "aws_vpc" "planetplant_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "planetplant-vpc"
    Environment = var.environment
  }
}

resource "aws_internet_gateway" "planetplant_igw" {
  vpc_id = aws_vpc.planetplant_vpc.id

  tags = {
    Name = "planetplant-igw"
    Environment = var.environment
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.planetplant_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "planetplant-public-subnet"
    Environment = var.environment
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.planetplant_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.planetplant_igw.id
  }

  tags = {
    Name = "planetplant-public-rt"
    Environment = var.environment
  }
}

resource "aws_route_table_association" "public_rta" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

# Security Groups
resource "aws_security_group" "planetplant_sg" {
  name_prefix = "planetplant-"
  vpc_id      = aws_vpc.planetplant_vpc.id
  description = "Security group for PlanetPlant application"

  # HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH (from specific IPs only)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidrs
  }

  # Backend API
  ingress {
    from_port   = 3001
    to_port     = 3001
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.planetplant_vpc.cidr_block]
  }

  # InfluxDB
  ingress {
    from_port   = 8086
    to_port     = 8086
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.planetplant_vpc.cidr_block]
  }

  # MQTT
  ingress {
    from_port   = 1883
    to_port     = 1883
    protocol    = "tcp"
    cidr_blocks = var.mqtt_allowed_cidrs
  }

  # MQTT WebSocket
  ingress {
    from_port   = 9001
    to_port     = 9001
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Grafana
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.planetplant_vpc.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "planetplant-security-group"
    Environment = var.environment
  }
}

# S3 Bucket for backups
resource "aws_s3_bucket" "backup_bucket" {
  bucket        = "${var.project_name}-backups-${var.environment}-${random_id.bucket_suffix.hex}"
  force_destroy = var.environment == "development"

  tags = {
    Name = "PlanetPlant Backups"
    Environment = var.environment
  }
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket_versioning" "backup_bucket_versioning" {
  bucket = aws_s3_bucket.backup_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_encryption" "backup_bucket_encryption" {
  bucket = aws_s3_bucket.backup_bucket.id

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "backup_bucket_lifecycle" {
  bucket = aws_s3_bucket.backup_bucket.id

  rule {
    id     = "delete_old_backups"
    status = "Enabled"

    expiration {
      days = var.backup_retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 7
    }
  }
}

# IAM for EC2 instance
resource "aws_iam_role" "planetplant_role" {
  name = "planetplant-ec2-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "planetplant_policy" {
  name = "planetplant-policy-${var.environment}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.backup_bucket.arn,
          "${aws_s3_bucket.backup_bucket.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "planetplant_policy_attachment" {
  role       = aws_iam_role.planetplant_role.name
  policy_arn = aws_iam_policy.planetplant_policy.arn
}

resource "aws_iam_instance_profile" "planetplant_profile" {
  name = "planetplant-profile-${var.environment}"
  role = aws_iam_role.planetplant_role.name
}

# Key Pair
resource "aws_key_pair" "planetplant_key" {
  key_name   = "planetplant-${var.environment}"
  public_key = var.public_key

  tags = {
    Name = "planetplant-${var.environment}"
    Environment = var.environment
  }
}

# Launch Template for Auto Scaling
resource "aws_launch_template" "planetplant_lt" {
  name_prefix   = "planetplant-${var.environment}-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = aws_key_pair.planetplant_key.key_name

  vpc_security_group_ids = [aws_security_group.planetplant_sg.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.planetplant_profile.name
  }

  user_data = base64encode(templatefile("${path.module}/user-data.sh", {
    domain_name           = var.domain_name
    influxdb_password     = var.influxdb_password
    influxdb_token        = var.influxdb_token
    redis_password        = var.redis_password
    jwt_secret            = var.jwt_secret
    grafana_password      = var.grafana_password
    backup_bucket         = aws_s3_bucket.backup_bucket.bucket
    aws_region            = var.aws_region
    slack_webhook         = var.slack_webhook
    cloudflare_zone_id    = var.cloudflare_zone_id
    cloudflare_api_token  = var.cloudflare_api_token
  }))

  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_size = var.root_volume_size
      volume_type = "gp3"
      encrypted   = true
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "planetplant-${var.environment}"
      Environment = var.environment
    }
  }
}

# Auto Scaling Group (for high availability)
resource "aws_autoscaling_group" "planetplant_asg" {
  name                = "planetplant-asg-${var.environment}"
  vpc_zone_identifier = [aws_subnet.public_subnet.id]
  min_size            = 1
  max_size            = 2
  desired_capacity    = 1
  health_check_type   = "ELB"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.planetplant_lt.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "planetplant-asg-${var.environment}"
    propagate_at_launch = false
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }
}

# Application Load Balancer
resource "aws_lb" "planetplant_alb" {
  name               = "planetplant-alb-${var.environment}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.planetplant_sg.id]
  subnets           = [aws_subnet.public_subnet.id]

  enable_deletion_protection = var.environment == "production"

  tags = {
    Name = "planetplant-alb-${var.environment}"
    Environment = var.environment
  }
}

# Target Group
resource "aws_lb_target_group" "planetplant_tg" {
  name     = "planetplant-tg-${var.environment}"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.planetplant_vpc.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 10
    interval            = 30
    path                = "/health"
    matcher             = "200"
    port                = "traffic-port"
    protocol            = "HTTP"
  }

  tags = {
    Name = "planetplant-tg-${var.environment}"
    Environment = var.environment
  }
}

# Auto Scaling Group Attachment
resource "aws_autoscaling_attachment" "planetplant_asg_attachment" {
  autoscaling_group_name = aws_autoscaling_group.planetplant_asg.id
  lb_target_group_arn    = aws_lb_target_group.planetplant_tg.arn
}

# Load Balancer Listeners
resource "aws_lb_listener" "planetplant_http" {
  load_balancer_arn = aws_lb.planetplant_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "planetplant_https" {
  count             = var.ssl_certificate_arn != "" ? 1 : 0
  load_balancer_arn = aws_lb.planetplant_alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = var.ssl_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.planetplant_tg.arn
  }
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "planetplant_logs" {
  name              = "/planetplant/${var.environment}"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "planetplant-logs-${var.environment}"
    Environment = var.environment
  }
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "planetplant-high-cpu-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors ec2 cpu utilization"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.planetplant_asg.name
  }

  tags = {
    Name = "planetplant-cpu-alarm-${var.environment}"
    Environment = var.environment
  }
}

# SNS Topic for alerts
resource "aws_sns_topic" "alerts" {
  name = "planetplant-alerts-${var.environment}"

  tags = {
    Name = "planetplant-alerts-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_sns_topic_subscription" "email_alerts" {
  count     = var.alert_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# Cloudflare DNS Records (for domain management)
resource "cloudflare_record" "planetplant_a" {
  zone_id = var.cloudflare_zone_id
  name    = var.environment == "production" ? "@" : var.environment
  value   = aws_lb.planetplant_alb.dns_name
  type    = "CNAME"
  ttl     = 300

  lifecycle {
    create_before_destroy = true
  }
}

resource "cloudflare_record" "planetplant_api" {
  zone_id = var.cloudflare_zone_id
  name    = var.environment == "production" ? "api" : "api-${var.environment}"
  value   = aws_lb.planetplant_alb.dns_name
  type    = "CNAME"
  ttl     = 300
}
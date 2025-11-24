# 1. ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.environment}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# 2. Cloud Map Namespace (Private DNS)
# Services will be reachable at http://service-name.dev.local
resource "aws_service_discovery_private_dns_namespace" "main" {
  name        = "${var.environment}.local"
  description = "Service discovery for ${var.environment}"
  vpc         = var.vpc_id
}
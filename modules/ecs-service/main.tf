# 1. Cloud Map Service (Internal DNS)
# This creates "http://app_name.environment.local"
resource "aws_service_discovery_service" "this" {
  name = var.app_name

  dns_config {
    namespace_id = var.service_discovery_namespace_id
    dns_records {
      ttl  = 10
      type = "A"
    }
    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

# 2. Target Group (CONDITIONAL: Only for Gateway)
resource "aws_lb_target_group" "this" {
  count       = var.is_public_gateway ? 1 : 0
  name        = "${var.environment}-${var.app_name}-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/"             # Change to root
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200-499"       # <--- NEW: Accept 200 OK and 404 Not Found
  }
}

# 3. Listener Rule (CONDITIONAL: Only for Gateway)
# This connects the ALB Listener -> Target Group
resource "aws_lb_listener_rule" "this" {
  count        = var.is_public_gateway ? 1 : 0
  listener_arn = var.alb_listener_arn

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this[0].arn
  }

  condition {
    path_pattern {
      values = ["/*"] # Kong handles all traffic
    }
  }
}

# 4. Task Definition
resource "aws_ecs_task_definition" "this" {
  family                   = "${var.environment}-${var.app_name}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([
    {
      name      = var.app_name
      image     = var.image_url
      essential = true
      portMappings = [
        {
          containerPort = var.container_port
          hostPort      = var.container_port
        }
      ]
      command = length(var.command) > 0 ? var.command : null
      environment = var.env_vars
      environment = var.env_vars
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/${var.environment}/${var.app_name}"
          "awslogs-region"        = "us-east-1" # Hardcoded for simplicity in this snippet, or pass as var
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

# 5. ECS Service
resource "aws_ecs_service" "this" {
  name            = "${var.environment}-${var.app_name}"
  cluster         = var.cluster_id
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnets
    security_groups  = var.security_group_ids
    assign_public_ip = false # Private subnet, so false
  }

  # Always register for Internal DNS
  service_registries {
    registry_arn = aws_service_discovery_service.this.arn
  }

  # Conditionally attach to ALB
  dynamic "load_balancer" {
    for_each = var.is_public_gateway ? [1] : []
    content {
      target_group_arn = aws_lb_target_group.this[0].arn
      container_name   = var.app_name
      container_port   = var.container_port
    }
  }
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/ecs/${var.environment}/${var.app_name}"
  retention_in_days = 7
}

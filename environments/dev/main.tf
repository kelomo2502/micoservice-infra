# environments/dev/main.tf
module "networking" {
  source = "../../modules/networking"

  environment          = var.environment
  vpc_cidr             = "10.0.0.0/16"
  availability_zones   = ["us-east-1a", "us-east-1b"]
  public_subnets_cidr  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets_cidr = ["10.0.10.0/24", "10.0.11.0/24"]
}

# NEW: Security Module
module "security" {
  source      = "../../modules/security"
  environment = var.environment
  vpc_id      = module.networking.vpc_id
  vpc_cidr    = module.networking.vpc_cidr_block
}

# NEW: Cluster Module
module "cluster" {
  source      = "../../modules/cluster"
  environment = var.environment
  vpc_id      = module.networking.vpc_id
}

# 1. ALB Module
module "alb" {
  source            = "../../modules/alb"
  environment       = var.environment
  vpc_id            = module.networking.vpc_id
  public_subnets    = module.networking.public_subnets
  security_group_id = module.security.alb_sg_id
}

# 2. Kong Gateway Service
module "kong" {
  source = "../../modules/ecs-service"

  environment        = var.environment
  app_name           = "kong"
  image_url          = "kong:3.4"
  container_port     = 8000
  cpu                = 512
  memory             = 1024
  desired_count      = 1

  vpc_id             = module.networking.vpc_id
  cluster_id         = module.cluster.cluster_id
  private_subnets    = module.networking.private_subnets
  security_group_ids = [module.security.ecs_tasks_sg_id]
  
  service_discovery_namespace_id = module.cluster.service_discovery_namespace_id
  execution_role_arn = module.security.ecs_execution_role_arn
  task_role_arn      = module.security.ecs_task_role_arn

  is_public_gateway  = true
  alb_listener_arn   = module.alb.listener_arn

  # --- THE MAGIC SAUCE: Runtime Config Injection ---
  # We use JSON because it is easier to format in Terraform than YAML
  command = [
    "/bin/sh", "-c",
    <<EOT
      cat <<EOF > /tmp/kong.json
      {
        "_format_version": "3.0",
        "services": [
          {
            "name": "service-a",
            "url": "http://service-a.dev.local:8080",
            "routes": [{ "name": "route-a", "paths": ["/service-a"], "strip_path": true }]
          },
          {
            "name": "service-b",
            "url": "http://service-b.dev.local:8080",
            "routes": [{ "name": "route-b", "paths": ["/service-b"], "strip_path": true }]
          },
          {
            "name": "service-c",
            "url": "http://service-c.dev.local:8080",
            "routes": [{ "name": "route-c", "paths": ["/service-c"], "strip_path": true }]
          }
        ]
      }
EOF
      export KONG_DATABASE="off"
      export KONG_DECLARATIVE_CONFIG="/tmp/kong.json"
      export KONG_PROXY_ACCESS_LOG="/dev/stdout"
      export KONG_ADMIN_ACCESS_LOG="/dev/stdout"
      export KONG_PROXY_ERROR_LOG="/dev/stderr"
      export KONG_ADMIN_ERROR_LOG="/dev/stderr"
      
      # Start Kong
      /docker-entrypoint.sh kong docker-start
    EOT
  ]

  # We clear env_vars because we set them in the command script above
  env_vars = []
}

# environments/dev/main.tf (Append this)

# --- Microservice A ---
module "service_a" {
  source = "../../modules/ecs-service"

  environment        = var.environment
  app_name           = "service-a"
  image_url          = "jmalloc/echo-server" # Lightweight dummy app
  container_port     = 8080
  cpu                = 256
  memory             = 512
  desired_count      = 1

  # Network & Infrastructure
  vpc_id             = module.networking.vpc_id
  cluster_id         = module.cluster.cluster_id
  private_subnets    = module.networking.private_subnets
  security_group_ids = [module.security.ecs_tasks_sg_id]
  
  # Service Discovery (Creates: service-a.dev.local)
  service_discovery_namespace_id = module.cluster.service_discovery_namespace_id
  
  # Permissions
  execution_role_arn = module.security.ecs_execution_role_arn
  task_role_arn      = module.security.ecs_task_role_arn

  # Env Vars (So the app knows who it is)
  env_vars = [
    { name = "PORT", value = "8080" }
  ]
}

# --- Microservice B ---
module "service_b" {
  source = "../../modules/ecs-service"

  environment        = var.environment
  app_name           = "service-b"
  image_url          = "jmalloc/echo-server"
  container_port     = 8080
  cpu                = 256
  memory             = 512
  desired_count      = 1

  vpc_id             = module.networking.vpc_id
  cluster_id         = module.cluster.cluster_id
  private_subnets    = module.networking.private_subnets
  security_group_ids = [module.security.ecs_tasks_sg_id]
  service_discovery_namespace_id = module.cluster.service_discovery_namespace_id
  execution_role_arn = module.security.ecs_execution_role_arn
  task_role_arn      = module.security.ecs_task_role_arn

  env_vars = [
    { name = "PORT", value = "8080" }
  ]
}

# --- Microservice C ---
module "service_c" {
  source = "../../modules/ecs-service"

  environment        = var.environment
  app_name           = "service-c"
  image_url          = "jmalloc/echo-server"
  container_port     = 8080
  cpu                = 256
  memory             = 512
  desired_count      = 1

  vpc_id             = module.networking.vpc_id
  cluster_id         = module.cluster.cluster_id
  private_subnets    = module.networking.private_subnets
  security_group_ids = [module.security.ecs_tasks_sg_id]
  service_discovery_namespace_id = module.cluster.service_discovery_namespace_id
  execution_role_arn = module.security.ecs_execution_role_arn
  task_role_arn      = module.security.ecs_task_role_arn

  env_vars = [
    { name = "PORT", value = "8080" }
  ]
}
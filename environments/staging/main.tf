# environments/staging/main.tf

# 1. Networking (New CIDR)
module "networking" {
  source = "../../modules/networking"

  environment          = var.environment
  vpc_cidr             = "10.1.0.0/16" # <--- DIFFERENT from Dev
  availability_zones   = ["us-east-1a", "us-east-1b"]
  public_subnets_cidr  = ["10.1.1.0/24", "10.1.2.0/24"]
  private_subnets_cidr = ["10.1.10.0/24", "10.1.11.0/24"]
}

# 2. Security
module "security" {
  source      = "../../modules/security"
  environment = var.environment
  vpc_id      = module.networking.vpc_id
  vpc_cidr    = module.networking.vpc_cidr_block
}

# 3. Cluster (Creates staging.local)
module "cluster" {
  source      = "../../modules/cluster"
  environment = var.environment
  vpc_id      = module.networking.vpc_id
}

# 4. ALB
module "alb" {
  source            = "../../modules/alb"
  environment       = var.environment
  vpc_id            = module.networking.vpc_id
  public_subnets    = module.networking.public_subnets
  security_group_id = module.security.alb_sg_id
}

# 5. Kong Gateway
module "kong" {
  source = "../../modules/ecs-service"

  environment          = var.environment
  app_name             = "kong"
  image_url            = "kong:3.4"
  container_port       = 8000
  cpu                  = 512
  memory               = 1024
  desired_count        = 1

  vpc_id               = module.networking.vpc_id
  cluster_id           = module.cluster.cluster_id
  private_subnets      = module.networking.private_subnets
  security_group_ids   = [module.security.ecs_tasks_sg_id]
  service_discovery_namespace_id = module.cluster.service_discovery_namespace_id
  execution_role_arn   = module.security.ecs_execution_role_arn
  task_role_arn        = module.security.ecs_task_role_arn

  is_public_gateway    = true
  alb_listener_arn     = module.alb.listener_arn

  # Runtime Config Injection (Updated for STAGING.LOCAL)
  command = [
    "/bin/sh", "-c",
    <<EOT
      cat <<EOF > /tmp/kong.json
      {
        "_format_version": "3.0",
        "services": [
          {
            "name": "service-a",
            "url": "http://service-a.staging.local:8080", 
            "routes": [{ "name": "route-a", "paths": ["/service-a"], "strip_path": true }]
          },
          {
            "name": "service-b",
            "url": "http://service-b.staging.local:8080",
            "routes": [{ "name": "route-b", "paths": ["/service-b"], "strip_path": true }]
          },
          {
            "name": "service-c",
            "url": "http://service-c.staging.local:8080",
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
      /docker-entrypoint.sh kong docker-start
    EOT
  ]
  env_vars = []
}

# 6. Microservices (A, B, C)
module "service_a" {
  source = "../../modules/ecs-service"
  environment = var.environment
  app_name = "service-a"
  image_url = "jmalloc/echo-server"
  container_port = 8080
  vpc_id = module.networking.vpc_id
  cluster_id = module.cluster.cluster_id
  private_subnets = module.networking.private_subnets
  security_group_ids = [module.security.ecs_tasks_sg_id]
  service_discovery_namespace_id = module.cluster.service_discovery_namespace_id
  execution_role_arn = module.security.ecs_execution_role_arn
  task_role_arn = module.security.ecs_task_role_arn
  env_vars = [{ name = "PORT", value = "8080" }]
}

module "service_b" {
  source = "../../modules/ecs-service"
  environment = var.environment
  app_name = "service-b"
  image_url = "jmalloc/echo-server"
  container_port = 8080
  vpc_id = module.networking.vpc_id
  cluster_id = module.cluster.cluster_id
  private_subnets = module.networking.private_subnets
  security_group_ids = [module.security.ecs_tasks_sg_id]
  service_discovery_namespace_id = module.cluster.service_discovery_namespace_id
  execution_role_arn = module.security.ecs_execution_role_arn
  task_role_arn = module.security.ecs_task_role_arn
  env_vars = [{ name = "PORT", value = "8080" }]
}

module "service_c" {
  source = "../../modules/ecs-service"
  environment = var.environment
  app_name = "service-c"
  image_url = "jmalloc/echo-server"
  container_port = 8080
  vpc_id = module.networking.vpc_id
  cluster_id = module.cluster.cluster_id
  private_subnets = module.networking.private_subnets
  security_group_ids = [module.security.ecs_tasks_sg_id]
  service_discovery_namespace_id = module.cluster.service_discovery_namespace_id
  execution_role_arn = module.security.ecs_execution_role_arn
  task_role_arn = module.security.ecs_task_role_arn
  env_vars = [{ name = "PORT", value = "8080" }]
}
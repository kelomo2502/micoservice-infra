variable "environment" { type = string }
variable "app_name" { type = string }
variable "image_url" { type = string }
variable "container_port" { type = number }

# Resource sizing
variable "cpu" {
  type    = number
  default = 256
}
variable "memory" {
  type    = number
  default = 512
}
variable "desired_count" {
  type    = number
  default = 1
}

# Infrastructure inputs
variable "vpc_id" { type = string }
variable "cluster_id" { type = string }
variable "private_subnets" { type = list(string) }
variable "security_group_ids" { type = list(string) }
variable "service_discovery_namespace_id" { type = string }
variable "execution_role_arn" { type = string }
variable "task_role_arn" { type = string }

# Gateway Logic (The "Switch")
variable "is_public_gateway" {
  description = "If true, creates a Target Group and attaches to ALB"
  type        = bool
  default     = false
}

variable "alb_listener_arn" {
  description = "ARN of the ALB listener (required if is_public_gateway is true)"
  type        = string
  default     = ""
}

# Environment Variables
variable "env_vars" {
  description = "List of environment variables"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "command" {
  description = "Override the container startup command"
  type        = list(string)
  default     = []
}
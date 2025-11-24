output "alb_dns_name" {
  description = "The public DNS name of the Load Balancer"
  value       = module.alb.alb_dns_name
}

output "kong_service_discovery_endpoint" {
  description = "Internal DNS for Kong"
  value       = "kong.${module.cluster.service_discovery_namespace_name}"
}
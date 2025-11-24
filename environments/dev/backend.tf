terraform {
  backend "s3" {
    bucket  = "microservice-infra-terraform-state-dev" # CHANGE THIS
    key     = "dev/networking/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}
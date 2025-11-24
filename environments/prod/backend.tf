terraform {
  backend "s3" {
    bucket         = "microservice-infra-terraform-state-dev"
    key            = "prod/networking/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-lock-table"
    encrypt        = true
  }
}
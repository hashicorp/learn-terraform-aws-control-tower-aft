terraform {
  required_version = ">= 1.6.1, < 2.0.0"

  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = ">= 4.67.0, < 5.0.0"
    }
  }
}
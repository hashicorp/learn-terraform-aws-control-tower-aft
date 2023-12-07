terraform {
  backend "s3" {
    region         = "eu-west-1"
    bucket         = "levi9-ct-aft-state"
    key            = "control/terraform.tfstate"
    assume_role = {
      role_arn = "arn:aws:iam::698876030372:role/PowerUser"
    }
  }
}
terraform {
  cloud {
    organization = "landing-zone-demo-org"

    workspaces {
      name = "easyservice-control"
    }
  }
}

# terraform {
#   backend "s3" {
#     bucket         = "democom-platform-state"
#     key            = "democom-dev/terraform.tfstate"
#     region         = "eu-west-1"
#     acl            = "bucket-owner-full-control"
#     encrypt        = "true"
#     role_arn       = "arn:aws:iam::012345678901:role/PowerUser"
#     dynamodb_table = "terraform-locking-table"
#   }
# }
# terraform {
#   backend "s3" {
#     bucket         = "project-terraform-state-bucket-redhat-lab"
#     key            = "infra-auto/terraform.tfstate"
#     region         = "ap-southeast-1"
#     dynamodb_table = "project-terraform-lock-table-redhat-lab"
#     encrypt        = true
#   }
# }

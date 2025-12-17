terraform {
  backend "s3" {
    bucket         = "b-eks-terraform-state-sandbox"
    key            = "sandbox/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-lock-table"
    encrypt        = true
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"   # Update to latest stable version

  name = "sandbox-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnets = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true

  tags = {
    Terraform   = "true"
    Environment = "sandbox"
  }
}

module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "~> 19.0"

  cluster_name    = "sandbox-eks-cluster"
  cluster_version = "1.30"
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.private_subnets

  cluster_endpoint_public_access       = true
  cluster_endpoint_private_access      = false 

  eks_managed_node_groups = {
    eks_nodes = {
      desired_capacity      = 2
      max_capacity          = 3
      min_capacity          = 1
      instance_type         = "t3.medium"
      create_security_group = true
    }
  }

  tags = {
    Environment = "sandbox"
  }
}


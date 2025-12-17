# Terraform AWS VPC, EKS & Optional RDS – Reusable Module Architecture

## Overview

This repository demonstrates a **production-style Terraform architecture** built around **reusable, composable modules**. It provisions:

* A secure **VPC** with public and private networking
* An **EKS cluster** with managed node groups
* An **optional RDS (or Aurora) database**, enabled only when workload requirements demand it

The design emphasizes **modularity, environment isolation, and operational best practices**

---

## Architecture

```
root/
├── modules/
│   ├── vpc/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── eks/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── rds/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
├── environments/
│   └── sandbox/
│       ├── main.tf
│       ├── backend.tf
│       ├── providers.tf
│       └── terraform.tfvars
└── README.md
```

Each module encapsulates a single responsibility, while environment folders act as **composition layers** that wire modules together.

---

## Versions

The repository uses explicit version constraints to ensure reproducibility:

* **Terraform**: `>= 1.5`
* **AWS Provider**: `~> 5.0`
* **VPC Module**: `terraform-aws-modules/vpc/aws ~> 5.0`
* **EKS Module**: `terraform-aws-modules/eks/aws ~> 20.0`
* **RDS Module**: `terraform-aws-modules/rds/aws ~> 6.0`

---

## State Management

Terraform state is managed remotely using:

* **S3 backend** for state storage
* **DynamoDB** for state locking and concurrency control

This prevents simultaneous applies, protects state integrity, and enables safe collaboration across teams.

Backend configuration is defined per environment in `backend.tf`.

---

## VPC Module (`modules/vpc`)

### Responsibilities

* Create a dedicated VPC
* Public and private subnets across multiple Availability Zones
* Internet Gateway and NAT Gateway
* Route tables and subnet associations

### Design Notes

The VPC module internally leverages the official `terraform-aws-modules/vpc/aws` module. Only required inputs and outputs are exposed, keeping the interface minimal and reusable across environments.

### Key Outputs

* `vpc_id`
* `private_subnets`
* `public_subnets`

---

## EKS Module (`modules/eks`)

### Responsibilities

* Provision EKS control plane
* Create managed node groups
* Establish cluster IAM roles and security boundaries

### Design Notes

The EKS module consumes networking outputs from the VPC module and uses **private subnets only** for worker nodes. Cluster configuration is intentionally opinionated but configurable via variables.

### Key Outputs

* `cluster_name`
* `cluster_endpoint`
* `cluster_security_group_id`

---

## RDS Module (`modules/rds`) — Optional

### Purpose

This module is **intentionally optional**. Many Kubernetes-based platforms operate without a traditional relational database by relying on:

* External SaaS databases
* Managed data services
* Event-driven or stateless architectures

When required, this module provisions a **private, highly available relational database**.

### Responsibilities

* RDS PostgreSQL instance (or Aurora-compatible replacement)
* DB subnet group (private subnets only)
* Database security group

### Design Notes

* The module creates and manages its own **DB subnet group** derived from private subnets
* No public accessibility is allowed
* The module can be swapped for **Aurora PostgreSQL** without impacting the VPC or EKS layers

---

## Environment Layer (`environments/sandbox`)

Environment folders define **how modules are composed**, not how they are implemented.

### `main.tf`

```hcl
module "vpc" {
  source = "../../modules/vpc"

  name            = "sandbox-vpc"
  cidr            = "10.0.0.0/16"
  azs             = ["us-east-1a", "us-east-1b"]
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets = ["10.0.101.0/24", "10.0.102.0/24"]
}

module "eks" {
  source = "../../modules/eks"

  cluster_name    = "sandbox-eks"
  cluster_version = "1.30"
  vpc_id          = module.vpc.vpc_id
  private_subnets = module.vpc.private_subnets
}

# Enable only when the workload requires a database
# module "rds" {
#   source = "../../modules/rds"
#
#   db_name        = "sandbox-db"
#   instance_class = "db.t3.micro"
#   username       = "admin"
#   password       = var.db_password
# }
```

---

## Deployment

From the environment directory:

```bash
terraform init
terraform plan
terraform apply
```

Configure Kubernetes access:

```bash
aws eks update-kubeconfig --name sandbox-eks --region us-east-1
kubectl get nodes
```

---

## Validation Checklist

* VPC created with public and private subnets
* EKS cluster reaches **ACTIVE** state
* Managed node group joins the cluster
* Kubernetes workloads deploy successfully
* Database (if enabled) is private and not internet-accessible

---

## Cluster Endpoint Access

### Sandbox Environment

- The EKS API endpoint is publicly accessible without IP restrictions.  
- This allows GitHub Actions runners (which have dynamic IPs) to connect and deploy ArgoCD and other resources.  
- Developers **may** connect directly for debugging using `kubectl` if needed, with access controlled via AWS IAM permissions.  
- This setup prioritizes ease of use and flexibility but is **not recommended for production** due to security risks.

### Production Environment (Best Practice)

- Restrict cluster API access by enabling private endpoint access and/or limiting public access to trusted IP ranges (CIDRs).  
- Use secure methods such as VPNs or AWS PrivateLink for accessing the cluster API.  
- Enforce strict IAM permissions and prefer automation pipelines (e.g., GitOps) for managing cluster changes.  
- This approach minimizes security risks while maintaining operational control.

## Why This Structure?

* **Separation of concerns** – Networking (VPC), compute (EKS), and data (RDS) are isolated into independent modules, making changes safer and easier to reason about.
* **Environment scalability** – The same modules can be reused across `sandbox`, `dev`, and `prod` by swapping only environment-level configuration.
* **Production alignment** – Mirrors how real platform teams manage Terraform: reusable modules, remote state, optional components, and clear ownership boundaries.

---


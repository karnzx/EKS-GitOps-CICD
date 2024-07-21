data "aws_availability_zones" "available" {}

data "aws_eks_cluster_auth" "cluster_auth" {
  name = module.eks.cluster_name
}

locals {
  name              = "ProjectU"
  rds_instance_name = "projectu-db"
  cluster_name      = local.name

  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 2) # 2 AZ (EKS required at least 2)

  tags = {
    Owner = "Terraform"
  }
}

## VPC
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.9.0"

  name = local.name
  cidr = local.vpc_cidr

  azs              = local.azs
  private_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k)]
  public_subnets   = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 48)]
  database_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 50)]

  create_database_subnet_group = true

  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
    "karpenter.sh/discovery"          = local.cluster_name
  }

  tags = merge(local.tags, {
    Module = "vpc"
  })
}


module "vpc_endpoints" {
  source  = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version = "5.9.0"

  vpc_id                     = module.vpc.vpc_id
  create_security_group      = true
  security_group_name_prefix = "${local.name}-vpc-endpoints-"
  # to ensure that the AWS CLI can send HTTPS requests to the AWS service
  security_group_rules = {
    ingress_https = {
      description = "HTTPS from VPC"
      cidr_blocks = [module.vpc.vpc_cidr_block]
    }
  }


  endpoints = {
    s3 = {
      service             = "s3"
      private_dns_enabled = true
      dns_options = {
        private_dns_only_for_inbound_resolver_endpoint = false
      }
      subnet_ids = module.vpc.private_subnets
      tags       = { Name = "s3-vpc-endpoint" }
    }
  }

  tags = merge(local.tags, {
    Module = "vpc_endpoints"
  })
}

## EKS

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.20"

  cluster_name                   = local.cluster_name
  cluster_version                = "1.30"
  cluster_endpoint_public_access = true

  # add Cluster creator as admin (one time operation)
  enable_cluster_creator_admin_permissions = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_addons = {
    coredns                = {}
    kube-proxy             = {}
    vpc-cni                = {}
    eks-pod-identity-agent = {}
  }

  eks_managed_node_groups = {
    karpenter = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = ["t3a.medium"]

      min_size     = 1
      max_size     = 2
      desired_size = 1

    }
  }

  node_security_group_tags = merge(local.tags, {
    # NOTE - if creating multiple security groups with this module, only tag the
    # security group that Karpenter should utilize with the following tag
    # (i.e. - at most, only one security group should have this tag in your account)
    "karpenter.sh/discovery" = local.cluster_name
  })

  tags = merge(local.tags, {
    Module = "eks"
  })
}

# karpenter
# Default SA for Pod identity accosiation is "kube-system:karpenter"
module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "~> 20.20"

  cluster_name = module.eks.cluster_name

  enable_pod_identity             = true
  create_pod_identity_association = true

  tags = merge(local.tags, {
    Module = "karpenter"
  })
}

# S3
resource "aws_s3_bucket" "projectu_s3_bucket" {
  bucket = "project-u-s3-bucket"

  tags = merge(local.tags, {
    Resource = "aws_s3_bucket.projectu_s3_bucket"
  })
}

resource "aws_s3_bucket_public_access_block" "projectu_s3_bucket" {
  bucket = aws_s3_bucket.projectu_s3_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# IAM Policy to access s3
module "projectu_s3_iam_policy" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-policy"
  version = "5.41.0"

  name = "projectu-s3-access-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:DeleteObject"
        ]
        Resource = [
          "${aws_s3_bucket.projectu_s3_bucket.arn}/*",
          "${aws_s3_bucket.projectu_s3_bucket.arn}"
        ]
      }
    ]
  })

  tags = merge(local.tags, {
    Module = "projectu_s3_iam_policy"
  })
}

# S3 IRSA
module "access_s3_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.41.0"

  role_name = "${module.eks.cluster_name}-access-s3"

  role_policy_arns = {
    policy = module.projectu_s3_iam_policy.arn
  }

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["default:access-s3-sa"]
    }
  }

  tags = merge(local.tags, {
    Module = "access_s3_irsa"
  })
}

module "ebs_csi_driver_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.41.0"

  role_name_prefix = "${module.eks.cluster_name}-ebs-csi-driver-"

  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }

  tags = merge(local.tags, {
    Module = "ebs_csi_driver_irsa"
  })
}

# RDS
module "rds" {
  source  = "terraform-aws-modules/rds/aws"
  version = "6.7.0"

  identifier = local.rds_instance_name

  engine               = "mysql"
  engine_version       = "8.0"
  family               = "mysql8.0" # DB parameter group
  major_engine_version = "8.0"      # DB option group
  instance_class       = "db.t4g.medium"
  allocated_storage    = 5

  # Database Deletion Protection
  deletion_protection = true

  db_name  = "db"
  username = "user"
  port     = "3306"

  iam_database_authentication_enabled = true

  db_subnet_group_name   = module.vpc.database_subnet_group_name
  vpc_security_group_ids = [module.rds_security_group.security_group_id]

  maintenance_window = "Sun:00:00-Sun:03:00"
  backup_window      = "03:00-06:00"

  monitoring_interval    = "60"
  create_monitoring_role = true

  tags = merge(local.tags, {
    Module = "rds"
  })

  parameters = [
    {
      name  = "character_set_client"
      value = "utf8mb4"
    },
    {
      name  = "character_set_server"
      value = "utf8mb4"
    }
  ]

}

# RDS Security Group
module "rds_security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = local.rds_instance_name
  description = "Complete MySQL example security group"
  vpc_id      = module.vpc.vpc_id

  # ingress
  ingress_with_cidr_blocks = [
    {
      from_port   = 3306
      to_port     = 3306
      protocol    = "tcp"
      description = "MySQL access from within VPC"
      cidr_blocks = module.vpc.vpc_cidr_block
    },
  ]

  tags = merge(local.tags, {
    Module = "rds_security_group"
  })
}

## Helm 
# bootstrap with Gitops

resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = "argocd"
  create_namespace = true
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "7.1.2" # app v2.11.3
  wait             = false
  values           = [templatefile("${path.module}/helm_values/argocd.yaml", {})]

  depends_on = [module.eks]
}

resource "helm_release" "argocd_apps" {
  name             = "argocd-apps"
  namespace        = "argocd"
  create_namespace = false
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argocd-apps"
  version          = "2.0.0"
  wait             = false
  values           = [templatefile("${path.module}/helm_values/argocd-apps.yaml", {})]

  depends_on = [helm_release.argocd]
}

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.27"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.13"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  backend "s3" {
    bucket         = "task-platform-tfstate-fcb7adf2"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "task-platform-tf-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "task-platform"
      ManagedBy = "Terraform"
    }
  }
}

provider "kubernetes" {
  host                   = aws_eks_cluster.main.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.main.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.main.token
}

provider "helm" {
  kubernetes {
    host                   = aws_eks_cluster.main.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.main.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.main.token
  }
}

data "aws_eks_cluster_auth" "main" {
  name = aws_eks_cluster.main.name
}

data "aws_availability_zones" "available" {}

# ─────────────────────────────────────────────────────────────────────────────
# VPC — public subnets only, NO NAT gateway
# ─────────────────────────────────────────────────────────────────────────────
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "task-platform-vpc"
    "kubernetes.io/cluster/task-platform-dev" = "shared"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "task-platform-igw" }
}

# 2 public subnets across 2 AZs (cheaper than 3, still HA enough for a project)
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet("10.0.0.0/16", 8, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name                     = "task-platform-public-${count.index}"
    "kubernetes.io/role/elb" = "1"
    "kubernetes.io/cluster/task-platform-dev" = "shared"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = { Name = "task-platform-public-rt" }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ─────────────────────────────────────────────────────────────────────────────
# Security Groups
# ─────────────────────────────────────────────────────────────────────────────
resource "aws_security_group" "eks_cluster" {
  name        = "task-platform-eks-cluster-sg"
  description = "EKS cluster control plane"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "eks_nodes" {
  name        = "task-platform-eks-nodes-sg"
  description = "EKS worker nodes"
  vpc_id      = aws_vpc.main.id

  # Nodes talk to each other
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  # Nodes accept traffic from cluster control plane
  ingress {
    from_port       = 1025
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_cluster.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "rds" {
  name        = "task-platform-rds-sg"
  description = "RDS PostgreSQL - EKS nodes only"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_nodes.id, "sg-02e64e1b8ec4b19dd"]
    description     = "PostgreSQL from EKS nodes"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# ─────────────────────────────────────────────────────────────────────────────
# IAM — EKS Cluster Role
# ─────────────────────────────────────────────────────────────────────────────
resource "aws_iam_role" "eks_cluster" {
  name = "task-platform-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# ─────────────────────────────────────────────────────────────────────────────
# IAM — Node Group Role
# ─────────────────────────────────────────────────────────────────────────────
resource "aws_iam_role" "eks_nodes" {
  name = "task-platform-eks-nodes-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "nodes_worker_policy" {
  role       = aws_iam_role.eks_nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "nodes_cni_policy" {
  role       = aws_iam_role.eks_nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "nodes_ecr_readonly" {
  role       = aws_iam_role.eks_nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# ─────────────────────────────────────────────────────────────────────────────
# EKS Cluster — public endpoint (no bastion needed, saves ~$8/mo)
# ─────────────────────────────────────────────────────────────────────────────
resource "aws_eks_cluster" "main" {
  name     = "task-platform-dev"
  role_arn = aws_iam_role.eks_cluster.arn
  version  = "1.29"

  vpc_config {
    subnet_ids              = aws_subnet.public[*].id
    security_group_ids      = [aws_security_group.eks_cluster.id]
    endpoint_public_access  = true    # access kubectl directly, no bastion
    endpoint_private_access = true
    public_access_cidrs     = ["0.0.0.0/0"]   # tighten to your IP: ["YOUR_IP/32"]
  }

  # Minimal logging to avoid CloudWatch costs
  enabled_cluster_log_types = []

  depends_on = [aws_iam_role_policy_attachment.eks_cluster_policy]
}

# OIDC Provider for IRSA
data "tls_certificate" "eks" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

# ─────────────────────────────────────────────────────────────────────────────
# EKS Node Group — single t3.medium, spot instances for max savings
# ─────────────────────────────────────────────────────────────────────────────
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "task-platform-ng"
  node_role_arn   = aws_iam_role.eks_nodes.arn
  subnet_ids      = aws_subnet.public[*].id

  # SPOT instances — ~70% cheaper than on-demand for a project
  capacity_type  = "SPOT"
  instance_types = ["t3.medium", "t3.large", "t3a.medium"]  # multiple types = better spot availability

  scaling_config {
    desired_size = 2
    min_size     = 1
    max_size     = 3
  }

  update_config {
    max_unavailable = 1
  }

  # IMDSv2 required
  launch_template {
    id      = aws_launch_template.nodes.id
    version = aws_launch_template.nodes.latest_version
  }

  depends_on = [
    aws_iam_role_policy_attachment.nodes_worker_policy,
    aws_iam_role_policy_attachment.nodes_cni_policy,
    aws_iam_role_policy_attachment.nodes_ecr_readonly,
  ]

  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }
}

resource "aws_launch_template" "nodes" {
  name_prefix   = "task-platform-node-"

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  tag_specifications {
    resource_type = "instance"
    tags = { Name = "task-platform-node" }
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# EKS Add-ons (only the essentials)
# ─────────────────────────────────────────────────────────────────────────────
resource "aws_eks_addon" "coredns" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "coredns"
  resolve_conflicts_on_update = "OVERWRITE"
  depends_on                  = [aws_eks_node_group.main]
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "kube-proxy"
  resolve_conflicts_on_update = "OVERWRITE"
}

resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "vpc-cni"
  resolve_conflicts_on_update = "OVERWRITE"
}

# ─────────────────────────────────────────────────────────────────────────────
# RDS — smallest possible, single-AZ, no Multi-AZ
# ─────────────────────────────────────────────────────────────────────────────
resource "aws_db_subnet_group" "main" {
  name       = "task-platform-rds-subnet-group"
  subnet_ids = aws_subnet.public[*].id   # public subnets (protected by SG)
}

resource "random_password" "db" {
  length           = 20
  special          = true
  override_special = "!#%&*-_=+?"
}

resource "aws_secretsmanager_secret" "db_password" {
  name                    = "task-platform/dev/db-credentials"
  recovery_window_in_days = 0   # instant delete — no 30-day hold cost
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id = aws_secretsmanager_secret.db_password.id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db.result
    host     = aws_db_instance.main.address
    port     = 5432
    dbname   = var.db_name
  })
}

resource "aws_db_instance" "main" {
  identifier        = "task-platform-dev"
  engine            = "postgres"
  engine_version    = "16.6"
  instance_class    = "db.t3.micro"   # free tier eligible!
  allocated_storage = 20
  storage_type      = "gp2"

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db.result

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  publicly_accessible     = false   # still not public, EKS nodes can reach it
  multi_az                = false   # single AZ — fine for a project
  skip_final_snapshot     = true    # easy destroy with no leftover snapshots
  deletion_protection     = false
  backup_retention_period = 1       # minimum backups
  storage_encrypted       = true

  tags = { Name = "task-platform-dev-rds" }
}

# ─────────────────────────────────────────────────────────────────────────────
# ECR — one repo per service
# ─────────────────────────────────────────────────────────────────────────────
resource "aws_ecr_repository" "backend" {
  name                 = "task-platform-backend"
  image_tag_mutability = "MUTABLE"
  force_delete         = true   # easy cleanup

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "frontend" {
  name                 = "task-platform-frontend"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
}

resource "aws_ecr_lifecycle_policy" "backend" {
  repository = aws_ecr_repository.backend.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 5 images only"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 5
      }
      action = { type = "expire" }
    }]
  })
}

resource "aws_ecr_lifecycle_policy" "frontend" {
  repository = aws_ecr_repository.frontend.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 5 images only"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 5
      }
      action = { type = "expire" }
    }]
  })
}

# ─────────────────────────────────────────────────────────────────────────────
# IRSA — Backend service account (Secrets Manager + S3)
# ─────────────────────────────────────────────────────────────────────────────
locals {
  oidc_url_stripped = replace(aws_iam_openid_connect_provider.eks.url, "https://", "")
}

resource "aws_iam_role" "backend_sa" {
  name = "task-platform-backend-sa-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.eks.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_url_stripped}:sub" = "system:serviceaccount:dev:backend-sa"
          "${local.oidc_url_stripped}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
}

resource "aws_iam_policy" "backend_sa" {
  name = "task-platform-backend-sa-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
        Resource = aws_secretsmanager_secret.db_password.arn
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
        Resource = [aws_s3_bucket.assets.arn, "${aws_s3_bucket.assets.arn}/*"]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "backend_sa" {
  role       = aws_iam_role.backend_sa.name
  policy_arn = aws_iam_policy.backend_sa.arn
}

# ─────────────────────────────────────────────────────────────────────────────
# S3 — Assets bucket
# ─────────────────────────────────────────────────────────────────────────────
resource "aws_s3_bucket" "assets" {
  bucket        = "task-platform-dev-assets-${random_id.bucket_suffix.hex}"
  force_destroy = true
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket_public_access_block" "assets" {
  bucket                  = aws_s3_bucket.assets.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ─────────────────────────────────────────────────────────────────────────────
# ALB Ingress Controller (needed for external access to the app)
# ─────────────────────────────────────────────────────────────────────────────
resource "aws_iam_role" "alb_controller" {
  name = "task-platform-alb-controller-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.eks.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_url_stripped}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
          "${local.oidc_url_stripped}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
}

data "http" "alb_policy" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.7.1/docs/install/iam_policy.json"
}

resource "aws_iam_policy" "alb_controller" {
  name   = "task-platform-alb-controller-policy"
  policy = data.http.alb_policy.response_body
}

resource "aws_iam_role_policy_attachment" "alb_controller" {
  role       = aws_iam_role.alb_controller.name
  policy_arn = aws_iam_policy.alb_controller.arn
}

resource "helm_release" "alb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "1.7.1"
  namespace  = "kube-system"

  set {
    name  = "clusterName"
    value = aws_eks_cluster.main.name
  }
  set {
    name  = "serviceAccount.create"
    value = "true"
  }
  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.alb_controller.arn
  }
  set {
    name  = "region"
    value = var.aws_region
  }
  set {
    name  = "vpcId"
    value = aws_vpc.main.id
  }

  depends_on = [aws_eks_node_group.main]
}

# ─────────────────────────────────────────────────────────────────────────────
# Kubernetes Namespace
# ─────────────────────────────────────────────────────────────────────────────
resource "kubernetes_namespace" "dev" {
  metadata {
    name = "dev"
    labels = { environment = "dev" }
  }
  depends_on = [aws_eks_cluster.main]
}

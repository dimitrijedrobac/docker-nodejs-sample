terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

locals {
  name      = "Devops"
  office_ip = "82.117.203.162/32"
  tags = {
    Name = "DevOps-course"
  }
}


provider "aws" {
  region = var.region

  default_tags {
    tags = var.default_tags
  }
}

# --- ECR Repository ---
resource "aws_ecr_repository" "repo" {
  name                 = var.ecr_repo_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  force_delete = true
}


# GitHub OIDC + IAM role for ECR

locals {
  github_repo_fullname = "dimitrijedrobac/docker-nodejs-sample"
  github_branch_ref    = "refs/heads/main"
}

# OIDC provider for GitHub Actions
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  # Current GitHub IdP thumbprint
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

# Trust policy: allow OIDC tokens from your repo/branch
data "aws_iam_policy_document" "github_oidc_assume_role" {
  statement {
    effect = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    # Audience must be sts.amazonaws.com
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Restrict to your repo + branch
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [
        "repo:${local.github_repo_fullname}:ref:${local.github_branch_ref}"
      ]
    }
  }
}

# --- Allow GitHub Actions OIDC role to deploy to EKS via Access Entries ---
resource "aws_eks_access_entry" "github_ci" {
  cluster_name  = "Devops-bottlerocket" 
  principal_arn = aws_iam_role.github_actions.arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "github_ci_edit" {
  cluster_name  = module.eks_bottlerocket.cluster_name
  principal_arn = aws_iam_role.github_actions.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [
    aws_iam_role_policy_attachment.github_ecr_attach,
    aws_iam_role_policy_attachment.github_attach_eks_describe
  ]
}


# Role that GitHub Actions will assume
resource "aws_iam_role" "github_actions" {
  name               = "github-actions-ecr-role"
  assume_role_policy = data.aws_iam_policy_document.github_oidc_assume_role.json
}

# ECR permissions for this role:

data "aws_iam_policy_document" "github_ecr" {
  statement {
    sid     = "GetAuthToken"
    effect  = "Allow"
    actions = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid    = "RepoPushPull"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:DescribeImages",
      "ecr:DescribeRepositories",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:ListImages",
      "ecr:PutImage",
      "ecr:UploadLayerPart"
    ]
    resources = [aws_ecr_repository.repo.arn]
  }
}

resource "aws_iam_policy" "github_ecr" {
  name   = "github-ecr-${aws_ecr_repository.repo.name}"
  policy = data.aws_iam_policy_document.github_ecr.json
}

resource "aws_iam_role_policy_attachment" "github_ecr_attach" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.github_ecr.arn
}

data "aws_iam_policy_document" "github_eks_describe" {
  statement {
    effect    = "Allow"
    actions   = ["eks:DescribeCluster"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "github_eks_describe" {
  name   = "github-eks-describe"
  policy = data.aws_iam_policy_document.github_eks_describe.json
}

resource "aws_iam_role_policy_attachment" "github_attach_eks_describe" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.github_eks_describe.arn
}

module "eks_bottlerocket" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = "${local.name}-bottlerocket"
  kubernetes_version = "1.33"

  # EKS Addons
  addons = {
    coredns = {}
    eks-pod-identity-agent = {
      before_compute = true
    }
    kube-proxy = {}
    vpc-cni = {
      before_compute = true
    }
  }

  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnets

  eks_managed_node_groups = {
    example = {
      ami_type       = "BOTTLEROCKET_x86_64"
      instance_types = ["t3.small"]

      min_size = 1
      max_size = 3
      desired_size = 2
    }
  }
}

module "alb_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.39"

  role_name = "${local.name}-alb-controller-irsa"

  # Built-in attachment for the official AWS Load Balancer Controller IAM policy
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    eks = {
      provider_arn               = module.eks_bottlerocket.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }

  tags = local.tags
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "ecr_repo_name" {
  description = "Name of the ECR repository"
  type        = string
  default     = "devops-course-repo"
}

variable "default_tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default = {
    Name = "DevOps-course"
  }
}

variable "vpc_id" {
  type    = string
  default = "vpc-0b82d505d3cab548a"
}

variable "private_subnets" {
  type    = list(string)
  default = ["subnet-018dc41558f747787", "subnet-0ccf4388c278e8321"]
}

variable "public_subnets" {
  type    = list(string)
  default = ["subnet-059ee7081eabf0133", "subnet-098f3ab66dd64cc60"]
}
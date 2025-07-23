variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev/prod)"
  type        = string
  default     = "prod"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "project_name" {
  description = "Project name for resource tagging"
  type        = string
  default     = "techeazy-devops"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "key_name" {
  description = "Name of the EC2 key pair"
  type        = string
  default     = "techeazy-key"
}

variable "repo_url" {
  description = "GitHub repository URL to clone."
  type        = string
  default     = "https://github.com/techeazy-consulting/techeazy-devops.git"
}

variable "shutdown_hours" {
  description = "Number of hours after which the instance will shut down."
  type        = number
  default     = 4
}

variable "java_package" {
  description = "Java package to install."
  type        = string
  default     = "openjdk-21-jdk"
}

variable "maven_package" {
  description = "Maven package to install."
  type        = string
  default     = "maven"
}

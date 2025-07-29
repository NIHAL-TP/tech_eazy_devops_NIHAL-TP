variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

# Removed ssh_private_key variable declaration to avoid prompt during terraform apply
# The private key content is read directly from file in main.tf

variable "environment" {
  description = "Environment name (dev/prod)"
  type        = string
  default     = "dev"
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
  default     = "https://github.com/Trainings-TechEazy/test-repo-for-devops.git"
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

variable "logs_bucket_name" {
  description = "Name of S3 bucket for logs. Must be provided via command line."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$", var.logs_bucket_name))
    error_message = "The bucket name must be provided and must be a valid S3 bucket name (lowercase letters, numbers, hyphens)."
  }
}

variable "upload_logs_on_shutdown" {
  description = "Whether to upload logs to S3 when the instance shuts down"
  type        = bool
  default     = true
}

variable "log_paths" {
  description = "List of log file paths to upload to S3"
  type        = list(string)
  default     = [
    "/var/log/cloud-init.log",
    "/var/log/user-data.log",
    "/home/ubuntu/techeazy-devops/app.log"
  ]
}

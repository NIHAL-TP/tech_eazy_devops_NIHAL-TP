provider "aws" {
  region = var.aws_region
}

# Create a new EC2 key pair
resource "aws_key_pair" "default" {
  key_name   = var.key_name
  public_key = file("~/.ssh/${var.key_name}.pub")
}

# VPC and Networking
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.project_name}-${var.environment}-vpc"
    Environment = var.environment
  }
}

# Public Subnet
resource "aws_subnet" "main" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "${var.aws_region}a"

  tags = {
    Name        = "${var.project_name}-${var.environment}-subnet"
    Environment = var.environment
  }
}

# Security Group with dynamic blocks
resource "aws_security_group" "app_sg" {
  name        = "${var.project_name}-${var.environment}-sg"
  description = "Security group for application"
  vpc_id      = aws_vpc.main.id

  dynamic "ingress" {
    for_each = [22, 80]
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-sg"
    Environment = var.environment
  }
}

# IAM Role for EC2
resource "aws_iam_role" "ec2_role" {
  name = "${var.project_name}-${var.environment}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

# Attach SSM policy to EC2 role
resource "aws_iam_role_policy_attachment" "ec2_ssm" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# EC2 Instance with proper user data
resource "aws_s3_bucket" "config_bucket" {
  bucket = "techeazy-devops-config"
  force_destroy = true
}

resource "aws_iam_policy" "s3_read_config" {
  name        = "${var.project_name}-${var.environment}-s3-read-config"
  description = "Allow EC2 to read config files from S3 bucket."
  policy      = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject"
        ],
        Resource = [
          "${aws_s3_bucket.config_bucket.arn}/*"
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "s3:ListBucket" # Permission to list objects within the bucket
        ],
        Resource = [
          aws_s3_bucket.config_bucket.arn # Apply to the bucket itself, not objects within it
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_s3_config" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.s3_read_config.arn
}

resource "null_resource" "upload_configs" {
  depends_on = [aws_s3_bucket.config_bucket]

  provisioner "local-exec" {
    command = "aws s3 cp ../config/${var.environment}.json s3://${aws_s3_bucket.config_bucket.bucket}/${var.environment}.json"
  }
}

# Main part of Assignment 2
#------------------------#

# S3 bucket for logs
resource "aws_s3_bucket" "logs" {
  bucket = var.logs_bucket_name
  force_destroy = true

  tags = {
    Name        = "${var.project_name}-${var.environment}-logs"
    Environment = var.environment
  }
}

# S3 bucket private access
resource "aws_s3_bucket_public_access_block" "logs" {
  bucket = aws_s3_bucket.logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 lifecycle rule
resource "aws_s3_bucket_lifecycle_configuration" "logs_lifecycle" {
  bucket = aws_s3_bucket.logs.id

  rule {
    id     = "delete_old_logs"
    status = "Enabled"

    filter {
      prefix = ""  # Apply to all objects
    }

    expiration {
      days = 7
    }
  }
}

# IAM role for upload-only S3 access (Assignment 2)
resource "aws_iam_role" "s3_upload" {
  name = "${var.project_name}-${var.environment}-s3-upload"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# Policy for upload-only role
resource "aws_iam_role_policy" "s3_upload" {
  name = "${var.project_name}-${var.environment}-s3-upload-policy"
  role = aws_iam_role.s3_upload.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          aws_s3_bucket.logs.arn,
          "${aws_s3_bucket.logs.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "sts:AssumeRole",
          "iam:GetRole",
          "iam:ListRoles"
        ]
        Resource = [
          aws_iam_role.s3_readonly.arn,
          "arn:aws:iam::*:role/${var.project_name}-${var.environment}-s3-*"
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ],
        Resource = [
          aws_s3_bucket.config_bucket.arn,
          "${aws_s3_bucket.config_bucket.arn}/*"
        ]
      }
    ]
  })
}

# IAM role for read-only S3 access (Assignment 2)
resource "aws_iam_role" "s3_readonly" {
  name = "${var.project_name}-${var.environment}-s3-readonly"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.s3_upload.arn
        }
      }
    ]
  })
}

# Policy for read-only role
resource "aws_iam_role_policy" "s3_readonly" {
  name = "${var.project_name}-${var.environment}-s3-readonly-policy"
  role = aws_iam_role.s3_readonly.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.logs.arn,
          "${aws_s3_bucket.logs.arn}/*"
        ]
      }
    ]
  })
}

# Instance Profile for EC2 - using upload role as per assignment
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-${var.environment}-ec2-profile"
  role = aws_iam_role.s3_upload.name
}

# Create an EC2 instance
resource "aws_instance" "app_server" {
  ami           = "ami-0c7217cdde317cfec"  # Ubuntu 22.04 LTS
  instance_type = "t2.micro"
  key_name      = aws_key_pair.default.key_name

  subnet_id                   = aws_subnet.main.id
  vpc_security_group_ids      = [aws_security_group.app_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name
  associate_public_ip_address = true

  user_data = templatefile("${path.module}/../scripts/user_data.sh.tpl", {
    stage = var.environment
    repo_url = var.repo_url
    shutdown_hours = var.shutdown_hours
    java_package = var.java_package
    maven_package = var.maven_package
    config_bucket = aws_s3_bucket.config_bucket.bucket
    logs_bucket = aws_s3_bucket.logs.bucket
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-app-server"
    Environment = var.environment
    Project     = var.project_name
    LogsBucket  = var.logs_bucket_name
  }
}

# Data source for latest Ubuntu 22.04 LTS AMI
# Canonical's owner ID: 099720109477
# Name pattern for Ubuntu 22.04 LTS: ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.project_name}-${var.environment}-igw"
    Environment = var.environment
  }
}

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-rt"
    Environment = var.environment
  }
}

# Associate Route Table with Public Subnet
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_route_table.public.id
}

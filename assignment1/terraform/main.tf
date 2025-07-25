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

# Instance Profile for EC2
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-${var.environment}-ec2-profile"
  role = aws_iam_role.ec2_role.name
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

resource "aws_instance" "app_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = aws_key_pair.default.key_name
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name
  subnet_id            = aws_subnet.main.id
  vpc_security_group_ids = [aws_security_group.app_sg.id]

  user_data = templatefile("${path.module}/../scripts/user_data.sh.tpl", {
    stage          = var.environment
    repo_url       = var.repo_url
    shutdown_hours = var.shutdown_hours
    java_package   = var.java_package
    maven_package  = var.maven_package
    config_bucket  = aws_s3_bucket.config_bucket.bucket
    ssh_private_key = file("~/.ssh/techeazy-key")
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-server"
    Environment = var.environment
  }

  volume_tags = {
    Name        = "${var.project_name}-${var.environment}-volume"
    Environment = var.environment
  }

  lifecycle {
    create_before_destroy = true
  }

  # Removed file and remote-exec provisioners
  # Removed connection block
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

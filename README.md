# TechEazy DevOps Assignment 1

This repository contains the implementation of TechEazy's DevOps Assignment 1 - Automated EC2 Deployment with multi-stage support and automated CI/CD pipeline.

## Features

- Automated EC2 instance deployment using Terraform
- Multi-stage deployment support (dev, prod, fix)
- GitHub Actions CI/CD pipeline
- Automated application deployment with Java 21 & Maven
- Stage-based configuration management via S3
- Auto-shutdown for cost optimization
- Health monitoring 

## Project Structure

```
assignment1/
├── config/              # Environment-specific configurations
│   ├── dev.json        # Development environment config
│   ├── prod.json       # Production environment config
│   └── fix.json        # Fix environment config
├── scripts/            # Deployment and utility scripts
│   ├── health_check.sh # Application health monitoring
│   └── user_data.sh.tpl# EC2 instance initialization
└── terraform/          # Infrastructure as Code
    ├── main.tf         # Main Terraform configuration
    ├── variables.tf    # Variable definitions
    ├── outputs.tf      # Output definitions
    └── *.tfvars       # Environment-specific variables
```

## Requirements

- AWS Account with appropriate permissions
- Terraform installed
- GitHub Actions enabled
- Java 21
- Maven

## Deployment

The deployment is automated via GitHub Actions and triggers on:
- Push to main, dev, prod, or fix branches
- Manual workflow dispatch

### Configuration

Environment-specific configurations are stored in `assignment1/config/` and include:
- Instance type
- Region settings
- Environment name
- Application port
- Shutdown timer
- Health check settings

### Security

- No hardcoded secrets (uses GitHub Secrets)
- IAM roles and policies
- Security group configurations
- Environment isolation

## Health Monitoring

The application includes health checks:
- Initial deployment verification
- Continuous health monitoring
- Configurable health check endpoints

## How to Deploy

### Prerequisites
- AWS Account
- GitHub Account
- Repository forked/cloned to your GitHub account

### 1. Configure GitHub Secrets
Navigate to your repository's Settings > Secrets and Variables > Actions and add:
```
AWS_ACCESS_KEY_ID       # Your AWS access key
AWS_SECRET_ACCESS_KEY   # Your AWS secret key
EC2_SSH_KEY            # Your SSH private key content
EC2_HOST               # Your EC2 instance public IP (after first deployment)
```

### 2. Deployment Environments
Choose your target environment by pushing to:
- **Production**: `main` branch
- **Development**: `dev` branch
- **Testing**: `fix` branch

### 3. Deployment Steps

1. **Push your changes**
```bash
git push origin <branch-name>
```

2. **Monitor Deployment**
- Go to repository's "Actions" tab
- Click on the running workflow
- Watch real-time deployment logs

3. **Access Application**
- URL: `http://<EC2_HOST>/hello`
- Replace `<EC2_HOST>` with your EC2 instance's public IP
- Allow 5-10 minutes for initial deployment

### Environment Configurations
Located in `assignment1/config/`:
```json
{
    "instance_type": "t2.micro",
    "region": "us-east-1",
    "environment": "dev|prod|fix",
    "app_port": 80,
    "shutdown_after_hours": 4
}
```

### Troubleshooting

1. **Failed Workflow**
- Check Actions tab error messages
- Verify AWS credentials
- Confirm IAM permissions

2. **Application Issues**
- Check EC2 instance logs
- Verify security group settings
- Confirm port 80 access

3. **Configuration Problems**
- Verify JSON syntax
- Check environment variables
- Confirm S3 bucket permissions

## Author

Nihal TP

## Assignment Requirements Met

1. ✅ AWS Free Tier Setup
2. ✅ EC2 Instance Deployment
3. ✅ Java 21 Installation
4. ✅ Maven Installation
5. ✅ GitHub Repo Clone & Deploy
6. ✅ Port 80 Access
7. ✅ Auto-shutdown
8. ✅ Secret Management
9. ✅ Stage-based Configuration
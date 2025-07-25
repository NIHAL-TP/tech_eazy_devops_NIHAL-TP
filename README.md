# TechEazy DevOps Assignment 1

This repository contains the implementation of TechEazy's DevOps Assignment 1 - Automated EC2 Deployment.

## Features

- Automated EC2 instance deployment using Terraform
- Multi-stage deployment support (dev, prod, fix)
- GitHub Actions CI/CD pipeline
- Automated application deployment
- Stage-based configuration management
- Auto-shutdown for cost optimization

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

## Author

[Your Name]

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
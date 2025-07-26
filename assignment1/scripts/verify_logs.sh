#!/bin/bash

# Enable error handling
set -e

# Check arguments
if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <stage> <logs_bucket_name>"
    echo "Example: $0 dev techeazy-logs-dev"
    exit 1
fi

STAGE=$1
LOGS_BUCKET=$2

# Enable logging
exec > >(tee verify-logs.log|logger -t verify-logs -s 2>/dev/console) 2>&1

echo "Starting log verification..."

# Assume read-only role
ROLE_ARN="arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/techeazy-${STAGE}-s3-readonly"
CREDS=$(aws sts assume-role --role-arn "$ROLE_ARN" --role-session-name "LogVerification")

# Export temporary credentials
export AWS_ACCESS_KEY_ID=$(echo $CREDS | jq -r '.Credentials.AccessKeyId')
export AWS_SECRET_ACCESS_KEY=$(echo $CREDS | jq -r '.Credentials.SecretAccessKey')
export AWS_SESSION_TOKEN=$(echo $CREDS | jq -r '.Credentials.SessionToken')

# Function to check log existence
check_log() {
    local log_path=$1
    local log_type=$2
    
    if aws s3 ls "s3://$LOGS_BUCKET/$STAGE/$log_path" &>/dev/null; then
        echo "✅ $log_type found at s3://$LOGS_BUCKET/$STAGE/$log_path"
        return 0
    else
        echo "❌ $log_type not found at s3://$LOGS_BUCKET/$STAGE/$log_path"
        return 1
    fi
}

# Initialize error counter
ERRORS=0

# Check system logs
echo "Checking system logs..."
check_log "system/cloud-init.log" "Cloud-init log" || ((ERRORS++))
check_log "system/user-data.log" "User-data log" || ((ERRORS++))
check_log "system/upload-logs.log" "Upload script log" || ((ERRORS++))

# Check application logs
echo "Checking application logs..."
check_log "app/logs/app.log" "Application log" || ((ERRORS++))

# Clear temporary credentials
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN

# Report results
echo "Verification complete."
if [ $ERRORS -eq 0 ]; then
    echo "✅ All logs verified successfully"
    exit 0
else
    echo "❌ Some logs are missing ($ERRORS errors found)"
    exit 1
fi 
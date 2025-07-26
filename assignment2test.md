# Assignment 2

## Prerequisites
- AWS CLI configured with admin credentials
- Terraform v1.0+ installed
- SSH key pair for EC2 access
- `jq` installed (`sudo apt-get install jq`)

## Setup Instructions

### 1. Clone Repository
```bash
### 1. Clone the Feature Branch
```bash
git clone -b assignment2 https://github.com/NIHAL-TP/tech_eazy_devops_NIHAL-TP.git #couldnt move it to feature/assignment2 beacause of the time constraint
cd assignment1/terraform

RUN
terraform init
terraform plan #-var-file="dev.tfvars" i have included .tfvars for dev and prod environment use any or none
terraform apply
for the infrastructure to provision,you should give a unique bucket name for s3
_______________________
Tests for assignment2
______________________

1)ROLE VERIFICATION TEST
1.1)UPLOAD ROLE FUNCTIONALITY
    # On EC2 instance:
$ aws sts get-caller-identity
{
    "Arn": "arn:aws:sts::977099000800:assumed-role/techeazy-devops-prod-s3-upload/i-0694200df70d85138"
}

# Test upload
$ echo "test" > testfile.txt
$ aws s3 cp testfile.txt s3://techeazy-logs-nihal-tp-2025/test-upload/
# Success: upload: ./testfile.txt to s3://techeazy-logs-nihal-tp-2025/test-upload/testfile.txt

# Test read (should fail)
$ aws s3 ls s3://techeazy-logs-nihal-tp-2025/
# Expected failure: An error occurred (AccessDenied)...
1.2)READ ONLY VALIDATION
# Using admin credentials:
$ aws iam get-role --role-name techeazy-devops-prod-s3-readonly
{
    "Role": {
        "Arn": "arn:aws:iam::977099000800:role/techeazy-devops-prod-s3-readonly",
        # ... (role details)
    }
}

# Test read-only access
$ CREDS=$(aws sts assume-role --role-arn arn:aws:iam::977099000800:role/techeazy-devops-prod-s3-readonly --role-session-name test)
$ export AWS_ACCESS_KEY_ID=$(echo $CREDS | jq -r .Credentials.AccessKeyId)
$ export AWS_SECRET_ACCESS_KEY=$(echo $CREDS | jq -r .Credentials.SecretAccessKey)
$ export AWS_SESSION_TOKEN=$(echo $CREDS | jq -r .Credentials.SessionToken)

$ aws s3 ls s3://techeazy-logs-nihal-tp-2025/
# Success: Lists objects

$ aws s3 cp testfile.txt s3://techeazy-logs-nihal-tp-2025/
# Expected failure: An error occurred (AccessDenied)...

2)S3 UPLOAD
2.1)PRIVACY TEST
    $ aws s3api get-public-access-block --bucket techeazy-logs-nihal-tp-2025
{
    "PublicAccessBlockConfiguration": {
        "BlockPublicAcls": true,
        "IgnorePublicAcls": true,
        "BlockPublicPolicy": true,
        "RestrictPublicBuckets": true
    }
}
2.2)LIFECYCLE RULES
    $ aws s3api get-bucket-lifecycle-configuration --bucket techeazy-logs-nihal-tp-2025
{
    "Rules": [
        {
            "ID": "delete_old_logs",
            "Status": "Enabled",
            "Expiration": { "Days": 7 }
        }
    ]
}

3)LOG UPLOAD FUNCTIONALITY
3.1)MANUAL EXECUTION
$ sudo /usr/local/sbin/upload_logs.sh
Starting log upload...
Uploading system logs...
Uploading application logs...
Log upload completed

# Verify logs:
$ aws s3 ls s3://techeazy-logs-nihal-tp-2025/prod/system/ --recursive
2025-07-26 12:01:22     142392 prod/system/cloud-init.log

3.2)SHUTDOWN HOOK TEST
$ sudo shutdown -h +1
# After 30 seconds:
$ sudo shutdown -c

# Verify shutdown logs:
$ aws s3 ls s3://techeazy-logs-nihal-tp-2025/prod/system/ | grep shutdown
2025-07-26 12:05:33       1056 prod/system/shutdown-log-20250726-120533.log

4)SECURITY VALIDATION
4.1)PERMISSION BOUNDARY TESTS
# From EC2:
$ aws iam list-roles
# Expected: AccessDenied

$ aws s3api get-bucket-acl --bucket techeazy-logs-nihal-tp-2025
# Expected: AccessDenied
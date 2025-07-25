#!/bin/bash
set -e

REPO_SSH_URL="https://github.com/Trainings-TechEazy/test-repo-for-devops.git"
APP_DIR="/home/ubuntu/techeazy-devops"
CONFIG_DIR="/home/ubuntu/config"
CONFIG_FILE="$CONFIG_DIR/config.json"
SHUTDOWN_HOURS="${shutdown_hours}"
JAVA_PACKAGE="${java_package}"
MAVEN_PACKAGE="${maven_package}"
STAGE="${stage}"
CONFIG_BUCKET="${config_bucket}"

sudo mkdir -p $CONFIG_DIR

# Install dependencies (including awscli and ssh client) first!
sudo apt-get update
sudo apt-get install -y $JAVA_PACKAGE $MAVEN_PACKAGE git jq curl awscli openssh-client

# Now download the correct config file from S3
aws s3 cp s3://$CONFIG_BUCKET/$STAGE.json $CONFIG_FILE

if [ -f "$CONFIG_FILE" ]; then
    SHUTDOWN_HOURS=$(jq -r '.shutdown_after_hours // empty' "$CONFIG_FILE")
    if [ -z "$SHUTDOWN_HOURS" ]; then
        SHUTDOWN_HOURS="${shutdown_hours}"
    fi
fi

sudo shutdown -h +$(( ${shutdown_hours} * 60 ))

#!/bin/bash
set -e

# Use SSH for Git cloning to avoid HTTPS auth issues
REPO_SSH_URL="git@github.com:Trainings-TechEazy/test-repo-for-devops.git"
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

# Setup SSH key for GitHub access
mkdir -p /home/ubuntu/.ssh
echo "${ssh_private_key}" > /home/ubuntu/.ssh/id_rsa
chmod 600 /home/ubuntu/.ssh/id_rsa
ssh-keyscan github.com >> /home/ubuntu/.ssh/known_hosts
chown -R ubuntu:ubuntu /home/ubuntu/.ssh

# Now download the correct config file from S3
aws s3 cp s3://$CONFIG_BUCKET/$STAGE.json $CONFIG_FILE

if [ -f "$CONFIG_FILE" ]; then
    SHUTDOWN_HOURS=$(jq -r '.shutdown_after_hours // empty' "$CONFIG_FILE")
    if [ -z "$SHUTDOWN_HOURS" ]; then
        SHUTDOWN_HOURS="${shutdown_hours}"
    fi
fi

echo "DEBUG: REPO_SSH_URL is $REPO_SSH_URL"
echo "DEBUG: APP_DIR is $APP_DIR"
if [ -d "$APP_DIR" ]; then
    echo "DEBUG: APP_DIR already exists, skipping clone"
else
    echo "DEBUG: APP_DIR does not exist, cloning repo"
    git clone "$REPO_SSH_URL" "$APP_DIR"
fi
cd "$APP_DIR"

mvn clean package

sudo nohup java -jar target/hellomvc-0.0.1-SNAPSHOT.jar --server.port=80 > app.log 2>&1 &
sleep 10
if ! pgrep -f 'java -jar'; then
  echo "Java app failed to start" >> app.log
  tail -n 50 app.log
  exit 1
fi

# Wait for the app to start with retries
max_retries=10
retry_count=0
until curl -f http://localhost:80/hello; do
    retry_count=$((retry_count+1))
    if [ $retry_count -ge $max_retries ]; then
        echo "App did not start correctly after $max_retries attempts."
        break
    fi
    echo "Waiting for app to start... attempt $retry_count"
    sleep 5
done

sudo shutdown -h +$(( ${shutdown_hours} * 60 )) 

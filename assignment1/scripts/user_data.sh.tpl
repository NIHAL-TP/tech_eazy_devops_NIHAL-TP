#!/bin/bash
set -e

REPO_URL="${repo_url}"
APP_DIR="/home/ubuntu/techeazy-devops"
CONFIG_DIR="/home/ubuntu/config"
CONFIG_FILE="$CONFIG_DIR/config.json"
SHUTDOWN_HOURS="${shutdown_hours}"
JAVA_PACKAGE="${java_package}"
MAVEN_PACKAGE="${maven_package}"
STAGE="${stage}"
CONFIG_BUCKET="${config_bucket}"

sudo mkdir -p $CONFIG_DIR

# Install dependencies (including awscli) first!
sudo apt-get update
sudo apt-get install -y $JAVA_PACKAGE $MAVEN_PACKAGE git jq curl awscli

# Now download the correct config file from S3
aws s3 cp s3://$CONFIG_BUCKET/$STAGE.json $CONFIG_FILE

if [ -f "$CONFIG_FILE" ]; then
    REPO_URL=$(jq -r '.repo_url // empty' "$CONFIG_FILE")
    if [ -z "$REPO_URL" ]; then
        REPO_URL="${repo_url}"
    fi
    SHUTDOWN_HOURS=$(jq -r '.shutdown_after_hours // empty' "$CONFIG_FILE")
    if [ -z "$SHUTDOWN_HOURS" ]; then
        SHUTDOWN_HOURS="${shutdown_hours}"
    fi
fi

echo "DEBUG: REPO_URL is $REPO_URL"
echo "DEBUG: APP_DIR is $APP_DIR"
if [ -d "$APP_DIR" ]; then
    echo "DEBUG: APP_DIR already exists, skipping clone"
else
    echo "DEBUG: APP_DIR does not exist, cloning repo"
    git clone "$REPO_URL" "$APP_DIR"
fi
cd "$APP_DIR"

mvn clean package

sudo nohup java -jar target/hellomvc-0.0.1-SNAPSHOT.jar --server.port=80 > app.log 2>&1 &

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

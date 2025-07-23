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
    REPO_URL=$(jq -r --arg def "$REPO_URL" '.repo_url // ($def)' "$CONFIG_FILE")
    SHUTDOWN_HOURS=$(jq -r --argjson def $shutdown_hours '.shutdown_after_hours // $def' "$CONFIG_FILE")
fi

if [ ! -d "$APP_DIR" ]; then
    git clone "$REPO_URL" "$APP_DIR"
fi
cd "$APP_DIR"

mvn clean package

sudo nohup java -jar target/techeazy-devops-0.0.1-SNAPSHOT.jar --server.port=80 > app.log 2>&1 &

sleep 10
curl -f http://localhost:80/ || echo "App did not start correctly."

sudo shutdown -h +$$(( ${shutdown_hours} * 60 )) 
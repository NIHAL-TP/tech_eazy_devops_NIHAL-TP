#!/bin/bash
set -e

# Update and install dependencies
sudo apt-get update
sudo apt-get install -y openjdk-21-jdk maven git jq curl

# Variables
REPO_URL="https://github.com/techeazy-consulting/techeazy-devops.git"
APP_DIR="/home/ubuntu/techeazy-devops"
CONFIG_FILE="/home/ubuntu/config.json"
SHUTDOWN_HOURS=4

# If config file exists, use its values
if [ -f "$CONFIG_FILE" ]; then
    REPO_URL=$(jq -r '.repo_url // "'$REPO_URL'"' "$CONFIG_FILE")
    SHUTDOWN_HOURS=$(jq -r '.shutdown_after_hours // 4' "$CONFIG_FILE")
fi

# Clone the repository
if [ ! -d "$APP_DIR" ]; then
    git clone "$REPO_URL" "$APP_DIR"
fi
cd "$APP_DIR"

# Build the application
mvn clean package

# Run the application on port 80
sudo nohup java -jar target/techeazy-devops-0.0.1-SNAPSHOT.jar --server.port=80 > app.log 2>&1 &

# Health check (optional, can be improved)
sleep 10
curl -f http://localhost:80/ || echo "App did not start correctly."

# Setup shutdown timer for cost saving
sudo shutdown -h +$((SHUTDOWN_HOURS * 60)) 
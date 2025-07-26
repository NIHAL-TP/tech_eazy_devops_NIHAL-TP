#!/bin/bash
set -e

# Enable logging
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

# Configure sudo access for ubuntu user
echo 'ubuntu ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/ubuntu
chmod 440 /etc/sudoers.d/ubuntu

# Assignment 1 variables
REPO_URL="${repo_url}"
APP_DIR="/home/ubuntu/techeazy-devops"
CONFIG_DIR="/home/ubuntu/config"
CONFIG_FILE="$CONFIG_DIR/config.json"
STAGE="${stage}"
CONFIG_BUCKET="${config_bucket}"
LOGS_BUCKET="${logs_bucket}"
JAVA_PACKAGE="${java_package}"
MAVEN_PACKAGE="${maven_package}"

echo "Starting instance setup for stage: $STAGE"
echo "Using config bucket: $CONFIG_BUCKET"

# Create necessary directories
sudo mkdir -p $CONFIG_DIR
sudo mkdir -p $APP_DIR
sudo chown -R ubuntu:ubuntu /home/ubuntu

# Create required directories
mkdir -p /app/logs
chown -R ubuntu:ubuntu /app/logs

# Install dependencies
echo "Installing dependencies..."
sudo apt-get update
sudo apt-get install -y $JAVA_PACKAGE $MAVEN_PACKAGE git jq curl awscli openssh-client at

# Install required packages
apt-get update
apt-get install -y awscli jq at

# Download config file from S3
echo "Downloading configuration from S3..."
echo "Attempting to download $STAGE.json from $CONFIG_BUCKET"
aws s3 cp s3://$CONFIG_BUCKET/$STAGE.json $CONFIG_FILE

# Initialize variables with defaults
SHUTDOWN_HOURS="${shutdown_hours}"  # Default from Terraform variables

if [ -f "$CONFIG_FILE" ]; then
    echo "Config file found for stage: $STAGE"
    
    # Read stage-specific settings
    STAGE_SHUTDOWN_HOURS=$(jq -r '.shutdown_after_hours // empty' "$CONFIG_FILE")
    STAGE_REPO_URL=$(jq -r '.repo_url // empty' "$CONFIG_FILE")
    STAGE_JAVA_PACKAGE=$(jq -r '.java_package // empty' "$CONFIG_FILE")
    STAGE_MAVEN_PACKAGE=$(jq -r '.maven_package // empty' "$CONFIG_FILE")

    # Use stage-specific values if available, otherwise keep defaults
    if [ ! -z "$STAGE_SHUTDOWN_HOURS" ]; then
        echo "Using stage-specific shutdown hours: $STAGE_SHUTDOWN_HOURS"
        SHUTDOWN_HOURS=$STAGE_SHUTDOWN_HOURS
    fi

    if [ ! -z "$STAGE_REPO_URL" ]; then
        echo "Using stage-specific repository: $STAGE_REPO_URL"
        REPO_URL=$STAGE_REPO_URL
    fi

    if [ ! -z "$STAGE_JAVA_PACKAGE" ]; then
        echo "Using stage-specific Java package: $STAGE_JAVA_PACKAGE"
        JAVA_PACKAGE=$STAGE_JAVA_PACKAGE
    fi

    if [ ! -z "$STAGE_MAVEN_PACKAGE" ]; then
        echo "Using stage-specific Maven package: $STAGE_MAVEN_PACKAGE"
        MAVEN_PACKAGE=$STAGE_MAVEN_PACKAGE
    fi
else
    echo "Warning: Config file not found for stage: $STAGE"
    echo "Using default settings from Terraform variables"
fi

# Log final configuration
echo "Final configuration:"
echo "- Stage: $STAGE"
echo "- Shutdown Hours: $SHUTDOWN_HOURS"
echo "- Repository: $REPO_URL"
echo "- Java Package: $JAVA_PACKAGE"
echo "- Maven Package: $MAVEN_PACKAGE"

# Clone and deploy application (Assignment 1)
cd /home/ubuntu
git clone ${repo_url} techeazy-devops
cd techeazy-devops

# Install Java and Maven
apt-get install -y ${java_package} ${maven_package}

# Build and run application with logs going to /app/logs
mvn clean package
nohup java -jar target/hellomvc-0.0.1-SNAPSHOT.jar --server.port=80 > /app/logs/app.log 2>&1 &

# Wait for application to start
for i in {1..30}; do
    if curl -s http://localhost:80/hello; then
        echo "Application started successfully!"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "Error: Application failed to start within 30 seconds"
        exit 1
    fi
    sleep 1
done

# Create log upload script
cat << 'EOF' > /usr/local/sbin/upload_logs.sh
#!/bin/bash
LOGS_BUCKET="${logs_bucket}"
STAGE="${stage}"

# Enable logging
exec > >(tee /var/log/upload-logs.log|logger -t upload-logs -s 2>/dev/console) 2>&1

echo "Starting log upload..."

# Upload system logs
echo "Uploading system logs..."
aws s3 cp /var/log/cloud-init.log s3://$LOGS_BUCKET/$STAGE/system/cloud-init.log || echo "Failed to upload cloud-init.log"
aws s3 cp /var/log/user-data.log s3://$LOGS_BUCKET/$STAGE/system/user-data.log || echo "Failed to upload user-data.log"
aws s3 cp /var/log/upload-logs.log s3://$LOGS_BUCKET/$STAGE/system/upload-logs.log || echo "Failed to upload upload-logs.log"

# Upload application logs
if [ -f "/app/logs/app.log" ]; then
    echo "Uploading application logs..."
    aws s3 cp /app/logs/app.log s3://$LOGS_BUCKET/$STAGE/app/logs/app.log || echo "Failed to upload app.log"
fi

echo "Log upload completed"
EOF

# Make script executable
chmod +x /usr/local/sbin/upload_logs.sh

# Create systemd service
cat << 'EOF' > /etc/systemd/system/upload-logs.service
[Unit]
Description=Upload logs to S3 on shutdown
DefaultDependencies=no
Before=shutdown.target reboot.target halt.target
Requires=network-online.target
After=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/upload_logs.sh
TimeoutStartSec=0
RemainAfterExit=yes

[Install]
WantedBy=halt.target reboot.target shutdown.target
EOF

# Enable and start the service
systemctl daemon-reload
systemctl enable upload-logs.service

# Create a welcome message
cat << EOF > /home/ubuntu/welcome.txt
Instance Setup Complete!
------------------------
Stage: $STAGE
Auto-shutdown: In $SHUTDOWN_HOURS hours
Config location: $CONFIG_FILE
Config bucket: $CONFIG_BUCKET
Logs bucket: $LOGS_BUCKET
Application: Running on port 80
Repository: $REPO_URL
Java package: $JAVA_PACKAGE
Maven package: $MAVEN_PACKAGE

The instance is ready and application is deployed.
Check /var/log/user-data.log for setup details.
EOF

echo "Instance setup completed successfully!"

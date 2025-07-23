#!/bin/bash

CONFIG_FILE="../config/${STAGE:-dev}.json"
APP_PORT=$(jq -r '.app_port // 80' "$CONFIG_FILE")
HEALTH_PATH=$(jq -r '.health_check_path // "/"' "$CONFIG_FILE")

URL="http://localhost:${APP_PORT}${HEALTH_PATH}"

for i in {1..10}; do
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$URL")
    if [ "$STATUS" == "200" ]; then
        echo "Health check passed: $URL (HTTP $STATUS)" | tee -a health_check.log
        exit 0
    else
        echo "Health check failed (attempt $i): $URL (HTTP $STATUS)" | tee -a health_check.log
        sleep 5
    fi
done

echo "Health check failed after 10 attempts: $URL" | tee -a health_check.log
exit 1 
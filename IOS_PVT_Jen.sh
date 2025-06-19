#Fix faulty IOS devices
#Usage: host_ip,udid

#!/bin/bash

# Colors for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

HOST_IP=$(echo "$SCRIPT_PARAMS" | cut -d "," -f 1)
DEVICE_UDID=$(echo "$SCRIPT_PARAMS" | cut -d "," -f 2)
USERNAME="$SERVER_USER"
PASSWORD="$SERVER_PASSWORD"
LOG_FILE="lamda-remote-runner-$DEVICE_UDID.log"
TOKEN_FILE="/Users/ltadmin/Documents/Configurator/tokens/token-${DEVICE_UDID}.key"

# Print header
echo -e "${BLUE}╔══════════════════════════════════════════════════╗"
echo -e "║           iOS Device Management Script           ║"
echo -e "╚══════════════════════════════════════════════════╝${NC}"
echo -e "${YELLOW}▶ Device UDID: ${DEVICE_UDID}${NC}"
echo -e "${YELLOW}▶ Host IP: ${HOST_IP}${NC}"
echo -e "${YELLOW}────────────────────────────────────────────────${NC}"

# SSH into the host and execute commands
{
sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no "$USERNAME@$HOST_IP" 2>/dev/null << EOF
    # Section 1: Device Verification
    echo "Verifying device UDID..."
    UDID=\$(/opt/homebrew/bin/idevice_id -l | grep "$DEVICE_UDID")
    
    if [ -z "\$UDID" ]; then
        echo -e "${RED}✖ ERROR: Device with UDID $DEVICE_UDID not found${NC}"
        exit 1
    else
        echo -e "${GREEN}✓ SUCCESS: Device UDID found: \$UDID${NC}"
    fi

    echo -e "${YELLOW}────────────────────────────────────────────────${NC}"
    sleep 2

    # Check if token file is present or not
    echo "Checking if passcode feature is provided or not..."
    echo -e "${YELLOW}────────────────────────────────────────────────${NC}"

    echo "🔍 Checking for token file: $TOKEN_FILE"

    echo -e "${YELLOW}────────────────────────────────────────────────${NC}"

if [[ -f "$TOKEN_FILE" ]]; then
    echo -e "${GREEN}✓ Token file found. Attempting to clear passcode...${NC}"
    
    RESPONSE=\$(curl -s --location 'localhost:9001/v1.0/device/clearPasscode' \
            --header 'Content-Type: application/json' \
            --data "{\"udid\":\"$DEVICE_UDID\"}")

     if [[ "\$RESPONSE" == *"success"* ]]; then
            echo -e "${GREEN}✓ Passcode cleared successfully${NC}"
        else
            echo -e "${RED}✖ ERROR: API Response: \$RESPONSE${NC}"
            exit 1
        fi

        echo -e "${YELLOW}────────────────────────────────────────────────${NC}"
    else
        echo -e "⚠ Token file not found. . Skipping passcode clear."
        echo -e "${YELLOW}────────────────────────────────────────────────${NC}"
    fi

    sleep 3

    # Section 3: Device Restart (always runs)
    echo "Initiating device restart..."
    /opt/homebrew/bin/idevicediagnostics -u "$DEVICE_UDID" restart

    if [[ \$? -eq 0 ]]; then
        echo -e "${GREEN}✓ SUCCESS: Restart command sent to device${NC}"
    else
        echo -e "${RED}✖ ERROR: Device restart failed${NC}"
        exit 1
    fi

    # Rest of the script (Plist reload, status check, etc.)
    echo -e "${YELLOW}────────────────────────────────────────────────${NC}"
    echo "Waiting for device to come back online..."
    sleep 15

    echo -e "${YELLOW}Reloading Plist...${NC}"
    cd ~/Documents/LambdaRemoteRunner/
    if ./reload_remoterunner_plist.sh "$DEVICE_UDID"; then
        echo -e "${GREEN}SUCCESS: Plist reloaded successfully${NC}"
    else
        echo -e "${RED}✖ ERROR: Plist reload failed${NC}"
        exit 1
    fi

    echo -e "${YELLOW}────────────────────────────────────────────────${NC}"
    echo -e "${GREEN}✔ All operations completed successfully${NC}"
    echo -e "${YELLOW}────────────────────────────────────────────────${NC}"

    echo "Waiting 2.5 minutes for device to become active..."
    sleep 150
    
    echo "Checking device status in LRR logs..."
    if tail -n 10 "$LOG_FILE" | grep -q 'lt-app response status code  -> 200'; then
        echo -e "${GREEN}✓ DEVICE IS ACTIVE: Status 200 found in logs${NC}"
    else
        echo -e "${YELLOW}⚠ WARNING: Device active status not confirmed in logs${NC}"
        echo -e "${RED}Last 10 log lines:"
        tail -n 10 "$LOG_FILE"
        echo -e "${NC}"
    fi
EOF
}

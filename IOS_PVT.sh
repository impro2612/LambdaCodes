#Fix faulty IOS PVT devices

#!/bin/bash

# Colors for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

HOST_IP=$1
DEVICE_UDID=$2
USERNAME="ltadmin"
PASSWORD="..."
LOG_FILE="lamda-remote-runner-$DEVICE_UDID.log"
CONFIG_FILE="/Users/ltadmin/Documents/LambdaRemoteRunner/.lrr.toml"

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
        echo -e "${RED}ERROR: Device with UDID $DEVICE_UDID not found${NC}"
        exit 1
    else
        echo -e "${GREEN}SUCCESS: Device UDID found: \$UDID${NC}"
    fi

    echo -e "${YELLOW}────────────────────────────────────────────────${NC}"
    sleep 2


    #check if passcode feature is provided
     # Check if cfgutil is enabled in .lrr.toml
    echo "Checking if passcode feature is provided or not..."
    echo -e "${YELLOW}────────────────────────────────────────────────${NC}"
    if grep -q "cfgutil" "$CONFIG_FILE"; then
    
    # Section 2: Passcode Clearing
    echo -e "${GREEN}✓ Found cfgutil in LRR config...Attempting to clear passcode...${NC}"
     RESPONSE=\$(curl -s --location 'localhost:9001/v1.0/device/clearPasscode' \
    --header 'Content-Type: application/json' \
    --data "{\"udid\":\"$DEVICE_UDID\"}")
    
    if [[ "\$RESPONSE" == *"success"* ]]; then
        echo -e "${GREEN}✓ Passcode cleared successfully${NC}"
    else
        echo -e "${RED}✖ ERROR: Failed to clear passcode${NC}"
        echo -e "API Response: \$RESPONSE"
        exit 1
    fi
        echo -e "${YELLOW}────────────────────────────────────────────────${NC}"
    else
        echo -e "⚠ cfgutil not found in LRR config. Skipping passcode clear."
        echo -e "${YELLOW}────────────────────────────────────────────────${NC}"
    fi

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

    # Section 4: Plist Reload
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


    echo "Waiting 2 minutes for device to become active..."
echo -e "${YELLOW}────────────────────────────────────────────────${NC}"    
    sleep 120
    
    # Check log file for successful response
    echo "Checking device status in LRR logs..."
    cd ~/Documents/LambdaRemoteRunner/
    if tail -n 5 "$LOG_FILE" | grep -q 'lt-app response status code  -> 200'; then
        echo -e "${GREEN}✓ DEVICE IS ACTIVE: Status 200 found in logs${NC}"
    else
        echo -e "${YELLOW}⚠ WARNING: Device active status not confirmed in logs${NC}"  
     fi
echo -e "${YELLOW}────────────────────────────────────────────────${NC}"      
EOF
}  

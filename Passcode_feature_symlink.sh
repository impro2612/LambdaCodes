#Provide Passcode feature using symlink 

#!/bin/bash

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

# Input parsing
IP=$(echo "$SCRIPT_PARAMS" | cut -d "," -f 1)
UDID=$(echo "$SCRIPT_PARAMS" | cut -d "," -f 2)
USERNAME="$SERVER_USER"
PASSWORD="$SERVER_PASSWORD"
REMOTE_APPS_DIR="/Applications"
REMOTE_CONFIG_FILE="/Users/$USERNAME/Documents/LambdaRemoteRunner/.lrr.toml"
REMOTE_CONFIG_DIR="/Users/$USERNAME/Documents/Configurator"
REMOTE_TOKENS_DIR="$REMOTE_CONFIG_DIR/tokens"

echo -e "${BLUE}╔══════════════════════════════════════════════════╗"
    echo -e "║          Passcode Feature Setup                  ║"
    echo -e "╚══════════════════════════════════════════════════╝${NC}"


# First check from Jenkins side if folder exists remotely
echo "Looking for Configurator directory on host"
sleep 3
if ! sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no "$USERNAME@$IP" '[ -d "/Users/'$USERNAME'/Documents/Configurator" ]'; then
    echo -e "${YELLOW}⚠️ Configurator folder not found. Copying...${NC}"
echo -e "${YELLOW}────────────────────────────────────────────────${NC}"
    # Create directory remotely
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no "$USERNAME@$IP" "mkdir -p /Users/$USERNAME/Documents/Configurator"

    if [[ "$IP" == 10.146.* ]]; then

# 1️⃣ Download from source remote to Jenkins workspace
echo "⬇️ Copying from source to Jenkins (Temporarily)"
sshpass -p "$PASSWORD" scp \
  -o StrictHostKeyChecking=no \
  -o PreferredAuthentications=password \
  -o PubkeyAuthentication=no \
  -o IdentitiesOnly=yes \
  -r "$USERNAME@10.146.0.130:$REMOTE_CONFIG_DIR" ./ConfiguratorTemp/

# 2️⃣ Upload from Jenkins to destination remote
echo "⬆️ Copying from Jenkins to $IP"
sshpass -p "$PASSWORD" scp \
  -o StrictHostKeyChecking=no \
  -o PreferredAuthentications=password \
  -o PubkeyAuthentication=no \
  -o IdentitiesOnly=yes \
  -r ./ConfiguratorTemp/* \
  "$USERNAME@$IP:$REMOTE_CONFIG_DIR"


elif [[ "$IP" == 10.151.* ]]; then
    # 1️⃣ Download from source remote to Jenkins workspace
echo "⬇️ Copying from source to Jenkins (intermediate)..."
sshpass -p "$PASSWORD" scp \
  -o StrictHostKeyChecking=no \
  -o PreferredAuthentications=password \
  -o PubkeyAuthentication=no \
  -o IdentitiesOnly=yes \
  -r lt@10.151.0.100:~/Desktop/LT ./ConfiguratorTemp/

# 2️⃣ Upload from Jenkins to destination remote
echo "⬆️ Copying from Jenkins to $IP"
sshpass -p "$PASSWORD" scp \
  -o StrictHostKeyChecking=no \
  -o PreferredAuthentications=password \
  -o PubkeyAuthentication=no \
  -o IdentitiesOnly=yes \
  -r ./ConfiguratorTemp/* \
  "$USERNAME@$IP:$REMOTE_CONFIG_DIR"

    elif [[ "$IP" == 10.100.* ]]; then
echo "⬇️ Copying from source to Jenkins (intermediate)..."
sshpass -p "$PASSWORD" scp \
  -o StrictHostKeyChecking=no \
  -o PreferredAuthentications=password \
  -o PubkeyAuthentication=no \
  -o IdentitiesOnly=yes \
  -r "$USERNAME@10.100.48.152:$REMOTE_CONFIG_DIR" ./ConfiguratorTemp/

# 2️⃣ Upload from Jenkins to destination remote
echo "⬆️ Copying from Jenkins to $IP"
sshpass -p "$PASSWORD" scp \
  -o StrictHostKeyChecking=no \
  -o PreferredAuthentications=password \
  -o PubkeyAuthentication=no \
  -o IdentitiesOnly=yes \
  -r ./ConfiguratorTemp/* \
  "$USERNAME@$IP:$REMOTE_CONFIG_DIR"

  rm -r ./ConfiguratorTemp/       
    fi
else
    echo -e "$GREEN✓ Configurator folder is already present on host $NC"
fi
echo -e "${YELLOW}────────────────────────────────────────────────${NC}"


script1() {
    local ssh_status=0
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no "$USERNAME@$IP" bash -s <<EOF || ssh_status=$?
     set -e
if [ ! -f /usr/local/bin/cfgutil ]; then
    echo "❌ cfgutil not found."
    exit 1
fi
sleep 2
 
    # Ensure cfgutil is present or not
echo "Looking for cgfutil configuration in LRR config file"
    if grep -q "cfgutil" "$REMOTE_CONFIG_FILE"; then
        echo -e "$GREEN✓ cfgutil found in .lrr.toml$NC"
    else
        echo -e "$YELLOW Not found - Adding cfgutil config to .lrr.toml... $NC"
        cat >> "$REMOTE_CONFIG_FILE" <<EOL

[cfgutil]
crtfile = "$REMOTE_CONFIG_DIR/LT.crt"
passfile = "$REMOTE_CONFIG_DIR/LT.der"
tokenfolder = "$REMOTE_TOKENS_DIR"
EOL
        echo -e "$GREEN✓ Configuration added$NC"
    fi
echo -e "${YELLOW}────────────────────────────────────────────────${NC}"
sleep 3

echo "Pulling out ECID for $UDID"
    ECID=\$(/usr/local/bin/cfgutil list | grep "$UDID" | awk '{print \$4}')
    if [ -z "\$ECID" ]; then
        echo -e "$RED ❌ ECID not found for UDID $UDID $NC"
        exit 1
    fi

    echo -e "$GREEN✓ Found ECID: \$ECID $NC"
sleep 3
echo -e "${YELLOW}────────────────────────────────────────────────${NC}"       

echo "Creating key for $UDID"
cd "$REMOTE_CONFIG_DIR"
if /usr/local/bin/cfgutil -e "\$ECID" -C LT.crt -K LT.der get-unlock-token | grep -v 'Waiting' | awk NF > "$REMOTE_CONFIG_DIR/$UDID.key"; then
       echo -e "$GREEN✓ Key created $NC"
else
    echo "❌ Failed to create key"
fi
sleep 3
echo -e "${YELLOW}────────────────────────────────────────────────${NC}" 

echo "Attempting to clear passcode"
echo -e "${YELLOW}────────────────────────────────────────────────${NC}"  
    /usr/local/bin/cfgutil -e "\$ECID" -C LT.crt -K LT.der clear-passcode "$UDID.key"
echo -e "${YELLOW}────────────────────────────────────────────────${NC}"     

echo "Creating unlock token"    
    if cp "$UDID.key" "$REMOTE_TOKENS_DIR/token-$UDID.key"; then
        echo -e "$GREEN✓ Token created $NC"
    else
        echo "❌ Failed to create Token"
    fi
echo -e "${YELLOW}────────────────────────────────────────────────${NC}" 

echo -e "${YELLOW}Reload plist for $UDID ${NC}"
echo -e "${YELLOW}────────────────────────────────────────────────${NC}"      
    sudo launchctl unload -w "/Library/LaunchDaemons/com.lambda.lambda_remote_runner_\$UDID.plist"
    sleep 3
    sudo launchctl load -w "/Library/LaunchDaemons/com.lambda.lambda_remote_runner_\$UDID.plist"
    sleep 5
echo -e "${YELLOW}────────────────────────────────────────────────${NC}" 
echo -e "${BLUE}Verifying the passcode feature once again${NC}"
echo -e "${YELLOW}────────────────────────────────────────────────${NC}"  
    if /usr/local/bin/cfgutil -e "\$ECID" -C LT.crt -K LT.der clear-passcode "$REMOTE_TOKENS_DIR/token-$UDID.key"; then
echo -e "${YELLOW}────────────────────────────────────────────────${NC}"         
    echo -e "$GREEN ✅ Passcode feature provided $NC"
echo -e "${YELLOW}────────────────────────────────────────────────${NC}"     
else
echo -e "${YELLOW}────────────────────────────────────────────────${NC}"     
    echo "❌ Failed to clear passcode"
echo -e "${YELLOW}────────────────────────────────────────────────${NC}"     
fi
EOF
    return $ssh_status
}

script2() {
    local ssh_status=0
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no "$USERNAME@$IP" bash -s <<'EOF' || ssh_status=$?
#!/bin/bash

set -e
trap 'echo "❌ Error on line $LINENO. Exiting."; exit 1' ERR

DMG_URL="http://10.151.0.100:9080/Apple_Configurator_2.16_Beta_3.dmg"
DMG_NAME="Apple_Configurator.dmg"
MOUNT_POINT="/Volumes/Configuration Utility Seed"
APP_NAME="Apple Configurator.app"
DEST_PATH="/Applications"
CFGUTIL_LINK="/usr/local/bin/cfgutil"

echo "📥 Downloading Apple Configurator DMG..."
cd ~/Downloads
curl -o "$DMG_NAME" "$DMG_URL"
sleep 3

echo "💽 Mounting the DMG..."
sudo hdiutil attach "$DMG_NAME"
sleep 5

echo "📦 Moving $APP_NAME to $DEST_PATH..."
sudo cp -R "$MOUNT_POINT/$APP_NAME" "$DEST_PATH/"
sleep 3

echo "🧹 Detaching the mounted DMG..."
sudo hdiutil detach "$MOUNT_POINT"
sleep 2

echo "🧽 Cleaning up downloaded DMG..."
rm -f "$DMG_NAME"
sleep 1

echo "🧼 Removing existing cfgutil binary if present..."
sudo rm -f "$CFGUTIL_LINK"
sleep 1

echo "🔗 Creating symlink for cfgutil..."
sudo ln -s "$DEST_PATH/$APP_NAME/Contents/MacOS/cfgutil" "$CFGUTIL_LINK"
sleep 1

echo "✅ Apple Configurator installed and cfgutil linked successfully!"

EOF
    return $ssh_status
}

# Main execution flow
echo "Checking for Apple Configurator on host"

if sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no "$USERNAME@$IP" \
   "[ -d '$REMOTE_APPS_DIR' ] && ls '$REMOTE_APPS_DIR' | grep -q 'Apple Configurator'"; then
    echo -e "${GREEN}✓ Apple Configurator found${NC}"
 echo -e "${YELLOW}────────────────────────────────────────────────${NC}"   
    if ! script1; then
        echo -e "${RED}❌ Passcode setup failed!${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}Apple Configurator not found - installing...${NC}"
 echo -e "${YELLOW}────────────────────────────────────────────────${NC}"     
    
    if ! script2; then
        echo -e "${RED}❌ Apple Configurator installation failed!${NC}"
        exit 1
    fi
echo -e "${YELLOW}────────────────────────────────────────────────${NC}"    
    echo -e "${GREEN}✅ Apple Configurator installation complete!${NC}"
echo -e "${YELLOW}────────────────────────────────────────────────${NC}"   
    if ! script1; then
        echo -e "${RED}❌ Passcode setup failed after installation!${NC}"
        exit 1
    fi
fi


echo -e "${BLUE}╔══════════════════════════════════════════════════╗"
echo -e "║          Script Execution Complete               ║"
echo -e "╚══════════════════════════════════════════════════╝${NC}"

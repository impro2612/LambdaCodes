#Provide Passcode feature using Apple script

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
set -e
trap 'echo "❌ Error on line \$LINENO. Installation failed."; exit 1' ERR

# ----------------------
# Configuration
# ----------------------
DMG_URL="http://10.146.0.100:9080/Apple_Configurator_2.16_Beta_3.dmg"
DMG_NAME="Apple_Configurator_2.16_Beta_3.dmg"
DOWNLOAD_DIR="/tmp"
DMG_PATH="$DOWNLOAD_DIR/$DMG_NAME"
MOUNT_POINT="/Volumes/AppleConfigurator"
APP_NAME="Apple Configurator.app"
DESTINATION="/Applications"
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
# ----------------------
# Step 1: Download DMG
# ----------------------
echo "📥 Downloading Apple Configurator to $DOWNLOAD_DIR"
mkdir -p "$DOWNLOAD_DIR"
cd "$DOWNLOAD_DIR"

if ! curl -L "$DMG_URL" -o "$DMG_NAME" --progress-bar --retry 3 --retry-delay 5; then
    echo "❌ Download failed!"
    exit 1
fi
echo -e "${YELLOW}────────────────────────────────────────────────${NC}" 
sleep 5

# ----------------------
# Step 2: Mount DMG
# ----------------------
echo "🔽 Mounting DMG..."
if [ ! -f "$DMG_PATH" ]; then
    echo "❌ DMG not found at $DMG_PATH"
    exit 1
fi

if ! hdiutil attach "$DMG_PATH" -mountpoint "$MOUNT_POINT" -nobrowse -quiet; then
    echo "❌ Failed to mount DMG."
    exit 1
fi
sleep 5

# ----------------------
# Cleanup Function
# ----------------------
cleanup() {
    if [ -d "$MOUNT_POINT" ]; then
        echo "🔽 Unmounting DMG..."
        hdiutil detach "$MOUNT_POINT" -quiet || true
        sleep 1
    fi
}
trap cleanup EXIT

# ----------------------
# Step 3: Copy App
# ----------------------
echo "🔍 Locating Apple Configurator app..."
APP_PATH=$(find "$MOUNT_POINT" -maxdepth 1 -name "*Apple Configurator*.app" -print -quit)

if [ -z "$APP_PATH" ]; then
    echo "❌ Could not find Apple Configurator app in DMG."
    exit 1
fi

sleep 2

echo "📦 Copying $(basename "$APP_PATH") to $DESTINATION..."
if ! cp -R "$APP_PATH" "$DESTINATION/"; then
    echo "❌ Copy failed."
    exit 1
fi

sleep 5

# ----------------------
# Step 4: Cleanup
# ----------------------
cleanup
cd "$DOWNLOAD_DIR"
rm -f "$DMG_NAME"

sleep 3  # Ensure cleanup settles

# ----------------------
# Step 5: Launch App
# ----------------------
INSTALLED_APP_NAME=$(basename "$APP_PATH" .app)
echo "🚀 Launching $INSTALLED_APP_NAME..."
open -a "$INSTALLED_APP_NAME"

sleep 10

    osascript <<EOF
    tell application "System Events"
        tell application process "Apple Configurator"
            -- Wait up to 3 seconds for the "Accept" button
            set waitCounter to 6 -- (3 seconds / 0.5)
            repeat until (exists button "Accept" of window 1) or (waitCounter = 0)
                delay 0.5
                set waitCounter to waitCounter - 1
            end repeat

            -- If the button appeared, click it
            if (exists button "Accept" of window 1) then
                click button "Accept" of window 1
                delay 3
            end if

            -- Trigger "Install Automation Tools…" from the menu
            click menu item "Install Automation Tools…" of menu "Apple Configurator" of menu bar 1
            delay 3

            -- Wait for and click the "Install" button
            repeat until (exists button "Install" of window 1)
                delay 3
            end repeat
            click button "Install" of window 1
        end tell

        delay 3

        -- Enter password in SecurityAgent prompt
        tell application process "SecurityAgent"
            repeat until (exists window 1)
                delay 0.2
            end repeat
            delay 0.5
            set value of text field 2 of window 1 to "password"
            click button "Add Helper" of window 1
        end tell
    end tell
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

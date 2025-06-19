#!/bin/bash

# Colors for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse input parameters
HOST_IP=$(echo "$SCRIPT_PARAMS" | cut -d "," -f 1)
XCODE_VERSION=$(echo "$SCRIPT_PARAMS" | cut -d "," -f 2)
USERNAME="$SERVER_USER"
PASSWORD="$SERVER_PASSWORD"
TARGET_DIR="/Applications"
DMG1="iOS_18_Simulator_Runtime.dmg"
DMG2="iOS_18.2_Simulator_Runtime.dmg"
DMG3="tvOS_18.2_Simulator_Runtime.dmg"


# Determine the correct XCODE_URL_BASE based on IP pattern
if [[ "$HOST_IP" == 10.100.* ]]; then
  XCODE_URL_BASE="http://10.100.48.65:9080"
elif [[ "$HOST_IP" == 10.151.* ]]; then
  XCODE_URL_BASE="http://10.151.0.100:9080"
elif [[ "$HOST_IP" == 10.146.* ]]; then
  XCODE_URL_BASE="http://10.146.0.100:9080"
fi

# Set filenames
XCODE_XIP="${XCODE_VERSION}.xip"
XCODE_APP="${XCODE_VERSION}.app"

echo -e "${BLUE}╔══════════════════════════════════════════════════╗"
    echo -e "║                  Xcode Setup                     ║"
    echo -e "╚══════════════════════════════════════════════════╝${NC}"


# Execute the remote script over SSH
sshpass -p "$PASSWORD" ssh -t -o StrictHostKeyChecking=no "$USERNAME@$HOST_IP" 2>/dev/null <<EOF
set -e
echo -e "${YELLOW}────────────────────────────────────────────────────────────────${NC}"
echo "🖥️ Connected to $HOST_IP"
echo -e "${YELLOW}────────────────────────────────────────────────────────────────${NC}"

if [[ -d "$TARGET_DIR/$XCODE_APP" ]]; then
  echo "✅ $XCODE_APP is already present"

else
  sleep 2
  echo "🌐 Downloading $XCODE_XIP from $XCODE_URL_BASE..."
  cd "$TARGET_DIR"
  /usr/bin/curl -# -o "$XCODE_XIP" "$XCODE_URL_BASE/$XCODE_XIP"
echo -e "${YELLOW}────────────────────────────────────────────────────────────────${NC}" 
  
  sleep 2
  echo "📦 Extracting $XCODE_XIP..."
  /usr/bin/xip -x "$XCODE_XIP"
  echo -e "${YELLOW}────────────────────────────────────────────────────────────────${NC}" 

  sleep 3
  echo "✏️ Renaming Xcode.app to $XCODE_APP"
  mv -f Xcode.app "$XCODE_APP"
  echo -e "${YELLOW}────────────────────────────────────────────────────────────────${NC}" 

  sleep 3
  echo "🧹 Cleaning up the XIP file..."
  rm -f "$XCODE_XIP"
  echo -e "${YELLOW}────────────────────────────────────────────────────────────────${NC}"  

  echo -e "${GREEN}✅ $XCODE_VERSION installed successfully${NC}"
fi
echo -e "${YELLOW}────────────────────────────────────────────────────────────────${NC}"

if [[ -n "$DEFAULT_XCODE" ]]; then
  sudo xcode-select -s "$TARGET_DIR/$DEFAULT_XCODE.app"
  echo -e "✅ Default Xcode set to: ${GREEN}\$(sudo xcode-select -p)${NC}"
fi

if [[ -z "$Simulator" ]]; then
  exit 0
fi
echo -e "${YELLOW}────────────────────────────────────────────────────────────────${NC}"

if [[ "$Simulator" == "18" ]]; then
  echo "🌐 Downloading iOS 18 Simulator from $XCODE_URL_BASE"
  /usr/bin/curl -# -o "\$HOME/Downloads/$DMG1" "$XCODE_URL_BASE/$DMG1"
elif [[ "$Simulator" == "18.2" ]]; then
  echo "🌐 Downloading iOS 18.2 Simulator from $XCODE_URL_BASE"
  /usr/bin/curl -# -o "\$HOME/Downloads/$DMG2" "$XCODE_URL_BASE/$DMG2"
elif [[ "$Simulator" == "tvOS_18.2" ]]; then
  echo "🌐 Downloading TV OS 18.2 Simulator from $XCODE_URL_BASE"
  /usr/bin/curl -# -o "\$HOME/Downloads/$DMG3" "$XCODE_URL_BASE/$DMG3"  
else
  echo "❌ Unsupported simulator version: $Simulator"
  exit 1
fi

echo -e "${YELLOW}────────────────────────────────────────────────────────────────${NC}"
  sleep 3
  echo "⚙️ Accepting Xcode license..."
  sudo xcodebuild -license accept

  sleep 2
  echo "⚙️ Running first launch setup..."
  sudo xcodebuild -runFirstLaunch

  sleep 2

  echo "⚙️ Configuring Simulator with Xcode..."
if [[ "$Simulator" == "18" ]]; then
  xcrun simctl runtime add "\$HOME/Downloads/$DMG1"
elif [[ "$Simulator" == "18.2" ]]; then
  xcrun simctl runtime add "\$HOME/Downloads/$DMG2"
elif [[ "$Simulator" == "tvOS_18.2" ]]; then
  xcrun simctl runtime add "\$HOME/Downloads/$DMG3"  
fi

  if [ \$? -eq 0 ]; then
echo -e "${YELLOW}────────────────────────────────────────────────────────────────${NC}" 
    echo "🧹 Cleaning up simulator DMG..."
    rm -f \$HOME/Downloads/iOS_18* \$HOME/Downloads/tvOS*
echo -e "${YELLOW}────────────────────────────────────────────────────────────────${NC}"       
 
    echo -e "${GREEN}✅ Simulator setup done${NC}"
echo -e "${YELLOW}────────────────────────────────────────────────────────────────${NC}"       
    
  else
    echo -e "${RED}❌ Failed to add Simulator${NC}"
    exit 1
  fi
EOF

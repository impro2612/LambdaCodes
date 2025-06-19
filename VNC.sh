#!/bin/bash

PASSWORD="pp123"

# Set up SSH tunnel
sshpass -p "$PASSWORD" ssh -L "$2":"$1":5900 pratikp@bastion-stage.lambdatest.com -N &
SSH_PID=$!

# Wait for the tunnel to establish
sleep 5

# Open VNC
open vnc://localhost:"$2"

# Wait for VNC viewer to fully launch
sleep 5

# Focus VNC window (optional: improve reliability)
osascript <<EOF
tell application "System Events"
    delay 2
    set frontmost of process "Screen Sharing" to true
    delay 2
    keystroke "ltadmin"
    key code 48 -- tab
    keystroke "lambdatest123!"
    key code 36 -- enter
    delay 3
    key code 48 -- tab again (if needed)
    key code 36 -- final enter
end tell
EOF

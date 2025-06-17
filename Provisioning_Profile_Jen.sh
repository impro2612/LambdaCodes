#to check whether provisioning is same on the hosts provided & resigner default
#usage 236,10.146.0.220,10.146.0.222

#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

USERNAME="$SERVER_USER"
PASSWORD="$SERVER_PASSWORD"

# Split into array
IFS=',' read -ra PARAMS <<< "$SCRIPT_PARAMS"

# Extract profile ID
PROFILE_ID="${PARAMS[0]}"
PROFILE_NAME="WildCardResignProfile${PROFILE_ID}.mobileprovision"

# Extract host IPs into array
HOSTS=("${PARAMS[@]:1}")

echo -e "${YELLOW}🔍 Connecting to hosts and associated Resigners to check profile...${NC}"

MATCH=true
OUTPUTS=()
RESIGNER_HOSTS_SET=()

# --- 1. Run on provided hosts and gather needed Resigners ---
for HOST in "${HOSTS[@]}"; do
    echo -e "${YELLOW}────────────────────────────────────────────────${NC}"
    echo -e "${GREEN}Host: $HOST${NC}"
    echo -e "${YELLOW}────────────────────────────────────────────────${NC}"


    # Regular host profile check
    REGULAR_RESULT=$(sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no "$USERNAME@$HOST" "bash -c '
        cd ~/Library/MobileDevice/Provisioning\\ Profiles/ 2>/dev/null && \
        echo -e \"${BLUE}▶ Checking in: \$(pwd)${NC}\" && \
        echo -e \"▶ List of Profile(s) found:\\n${GREEN}\$(ls)${NC}\" && \
        security cms -Di $PROFILE_NAME | grep date || echo \"\"
    '" 2>/dev/null)

    if [ -z "$REGULAR_RESULT" ]; then
        echo "❌ Unable to read date from profile on host: $HOST"
        MATCH=false
    else
        echo "📄 Getting date info from $HOST"
        echo "$REGULAR_RESULT"
        # Collapse multiline into one line with semicolons to keep OUTPUTS array clean
        CLEAN_RESULT=$(echo "$REGULAR_RESULT" | tr '\n' ';')
        OUTPUTS+=("$HOST|$CLEAN_RESULT")
    fi

    # Append relevant Resigner IPs (avoid duplicates using array)
    if [[ "$HOST" == 10.146.* ]]; then
        RESIGNER_HOSTS_SET+=("10.146.0.205" "10.146.0.207")
    elif [[ "$HOST" == 10.151.* ]]; then
        RESIGNER_HOSTS_SET+=("10.151.0.205" "10.151.0.207")
    elif [[ "$HOST" == 10.100.* ]]; then
        RESIGNER_HOSTS_SET+=("10.100.48.205" "10.100.48.207") 
    fi
done

# --- 2. Remove duplicate Resigner IPs ---
mapfile -t UNIQUE_RESIGNERS < <(printf "%s\n" "${RESIGNER_HOSTS_SET[@]}" | sort -u)

# --- 3. Run checks on unique Resigners ---
for RESIGNER in "${UNIQUE_RESIGNERS[@]}"; do
    echo -e "${YELLOW}────────────────────────────────────────────────${NC}"
    echo -e "\n${GREEN}🔧 Resigner Host: $RESIGNER${NC}"
    echo -e "${YELLOW}────────────────────────────────────────────────${NC}"

    # Run command in first resigner path with pwd
    RESULT1=$(sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no "$USERNAME@$RESIGNER" "bash -c '
        cd ~/Documents/iOS-Resigner/ProvisioningProfiles/ 2>/dev/null && \
        echo -e \"${BLUE}▶ Checking in: \$(pwd)${NC}\" && \
        security cms -Di $PROFILE_NAME | grep date || echo \"\"
    '" 2>/dev/null)

    # Run command in second resigner path with pwd
    RESULT2=$(sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no "$USERNAME@$RESIGNER" "bash -c '
        cd ~/Desktop/ 2>/dev/null && \
        echo -e \"${BLUE}▶ Checking in: \$(pwd)${NC}\" && \
        security cms -Di $PROFILE_NAME | grep date || echo \"\"
    '" 2>/dev/null)

    # Combine outputs, ignoring empty results
    if [ -n "$RESULT1" ] && [ -n "$RESULT2" ]; then
        RESIGNER_RESULT="${RESULT1}"$'\n'"${RESULT2}"
    elif [ -n "$RESULT1" ]; then
        RESIGNER_RESULT="$RESULT1"
    elif [ -n "$RESULT2" ]; then
        RESIGNER_RESULT="$RESULT2"
    else
        RESIGNER_RESULT=""
    fi

    if [ -z "$RESIGNER_RESULT" ]; then
        echo "❌ Unable to read date from profile on Resigner: $RESIGNER"
        MATCH=false
    else
        echo "📄 Getting date info from Resigner $RESIGNER:"
        echo "$RESIGNER_RESULT"
        CLEAN_RESULT=$(echo "$RESIGNER_RESULT" | tr '\n' ';')
        OUTPUTS+=("$RESIGNER|$CLEAN_RESULT")
    fi
done



# --- 4. Compare only unique date values (no tags, only timestamp strings) ---
if [ "$MATCH" = true ]; then
    # Get sorted, unique date values from the first entry
    first_output_dates=$(echo "${OUTPUTS[0]#*|}" | tr ';' '\n' | grep "<date>" | sed -E 's|<date>(.*)</date>|\1|' | sort -u)

    for entry in "${OUTPUTS[@]}"; do
        ip="${entry%%|*}"
        output="${entry#*|}"
        current_dates=$(echo "$output" | tr ';' '\n' | grep "<date>" | sed -E 's|<date>(.*)</date>|\1|' | sort -u)

        if [ "$current_dates" != "$first_output_dates" ]; then
            MATCH=false
            echo -e "\n${RED}❌ Mismatch found on IP: $ip${NC}"
            echo "$current_dates"
        fi
    done

    if [ "$MATCH" = true ]; then
        echo -e "\n ${GREEN}✅ All profile dates match across hosts and resigners.${NC}"
    else
        echo -e "\n${RED}⚠️ Mismatch detected in profile dates!${NC}"
    fi
else
    echo -e "\n${YELLOW}⚠️ Some hosts failed to provide valid date info.${NC}"
fi

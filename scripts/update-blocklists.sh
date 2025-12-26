#!/bin/bash

# Default values
CONFIG_FILE=""
OUTPUT_FILE=""

# Usage function
usage() {
    echo "Usage: $0 -c <config_file> -o <output_file>"
    exit 1
}

# Parse arguments
while getopts "c:o:" opt; do
    case "$opt" in
    c) CONFIG_FILE="$OPTARG" ;;
    o) OUTPUT_FILE="$OPTARG" ;;
    *) usage ;;
    esac
done

if [ -z "$CONFIG_FILE" ] || [ -z "$OUTPUT_FILE" ]; then
    usage
fi

# Load configuration
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    echo "Error: Configuration file not found at $CONFIG_FILE"
    exit 1
fi

if [ -z "$URL" ]; then
    echo "Error: No URL defined in $CONFIG_FILE"
    exit 1
fi

echo "Downloading blocklist from $URL..."

# Create a temporary file
TEMP_FILE=$(mktemp)

# Download
# using curl. Fail silently (-s) but show errors (-S), follow redirects (-L)
if curl -sSL "$URL" -o "$TEMP_FILE"; then
    # basic validation: check if file is not empty
    if [ -s "$TEMP_FILE" ]; then
        echo "Download successful."
        
        # Move to destination
        mv "$TEMP_FILE" "$OUTPUT_FILE"
        chmod 644 "$OUTPUT_FILE"
        
        echo "Blocklist updated at $OUTPUT_FILE"
        
        # Restart/Reload DNSMasq
        if [[ "$OSTYPE" == "darwin"* ]]; then
             # macOS
             # Assuming running as root or user with sudo rights for brew services? 
             # Often brew services doesn't need sudo if installed as user, but dnsmasq on port 53 usually needs root.
             # We will try sudo first if we are not root.
             if [ "$EUID" -ne 0 ]; then
                 sudo brew services restart dnsmasq
             else
                 brew services restart dnsmasq
             fi
        elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
             # Linux
             systemctl restart dnsmasq
        else
             echo "Unknown OS. Please restart dnsmasq manually."
        fi
    else
        echo "Error: Downloaded file is empty."
        rm "$TEMP_FILE"
        exit 1
    fi
else
    echo "Error: Failed to download blocklist."
    rm "$TEMP_FILE"
    exit 1
fi

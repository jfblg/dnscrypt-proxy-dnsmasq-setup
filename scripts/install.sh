#!/bin/bash

# install.sh
# Main entry point for DNS Privacy Setup

chmod +x scripts/*.sh

echo "Welcome to the DNS Privacy Setup (dnscrypt-proxy + dnsmasq)"
echo "---------------------------------------------------------"

ARGS="$@"

OS="$(uname -s)"
case "$OS" in
    Darwin)
        echo "Detected macOS."
        ./scripts/setup_macos.sh $ARGS
        ;;
    Linux)
        echo "Detected Linux."
        ./scripts/setup_linux.sh $ARGS
        ;;
    *)
        echo "Unsupported Operating System: $OS"
        exit 1
        ;;
esac
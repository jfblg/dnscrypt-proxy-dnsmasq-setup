#!/bin/bash

# uninstall.sh
# Removes configuration and services installed by this project.

set -e

DRY_RUN=false
for arg in "$@"; do
    if [ "$arg" == "--dry-run" ]; then
        DRY_RUN=true
        echo ">>> DRY RUN MODE ACTIVATED: No changes will be made."
    fi
done

run_cmd() {
    if [ "$DRY_RUN" = true ]; then
        echo "[DRY RUN] $*"
    else
        "$@"
    fi
}

remove_symlink_or_file() {
    local target="$1"
    local sudo_cmd="$2"

    if [ -e "$target" ] || [ -L "$target" ]; then
        echo "Removing $target..."
        $sudo_cmd run_cmd rm "$target"
        
        # Restore backup if exists
        if [ -f "$target.bak" ]; then
            echo "Restoring backup $target.bak -> $target..."
            $sudo_cmd run_cmd mv "$target.bak" "$target"
        fi
    else
        echo "Not found: $target"
    fi
}

OS="$(uname -s)"

echo "Uninstalling DNS Privacy Setup..."

if [ "$OS" == "Darwin" ]; then
    # macOS Uninstallation
    BREW_PREFIX=$(brew --prefix)
    ETC_DIR="$BREW_PREFIX/etc"
    BIN_DIR="/usr/local/bin"
    PLIST_DEST="/Library/LaunchDaemons/com.user.dns-blocklist-update.plist"

    # Stop Services
    echo "Stopping services..."
    run_cmd sudo launchctl unload "$PLIST_DEST" 2>/dev/null || true
    # We don't uninstall brew packages as user might use them for other things.
    # Just stop them.
    run_cmd sudo brew services stop dnscrypt-proxy
    run_cmd sudo brew services stop dnsmasq

    # Remove Files/Links
    remove_symlink_or_file "$PLIST_DEST" "sudo"
    remove_symlink_or_file "$BIN_DIR/dns-blocklist-update.sh" "sudo"
    remove_symlink_or_file "$ETC_DIR/dns-blocklists.conf" ""
    remove_symlink_or_file "$ETC_DIR/dnscrypt-proxy.toml" ""
    remove_symlink_or_file "$ETC_DIR/dnsmasq.conf" ""
    
    # Clean up generated blocklist
    if [ -f "$ETC_DIR/dnsmasq.d/hagezi.conf" ]; then
        echo "Removing generated blocklist..."
        run_cmd rm "$ETC_DIR/dnsmasq.d/hagezi.conf"
    fi

    echo "Uninstallation complete. Note: 'dnscrypt-proxy' and 'dnsmasq' packages were NOT removed."

elif [ "$OS" == "Linux" ]; then
    # Linux Uninstallation
    BIN_DIR="/usr/local/bin"
    SERVICE_DEST="/etc/systemd/system/dns-blocklist-update.service"
    TIMER_DEST="/etc/systemd/system/dns-blocklist-update.timer"
    
    # Stop Services
    echo "Stopping services..."
    run_cmd sudo systemctl stop dns-blocklist-update.timer
    run_cmd sudo systemctl disable dns-blocklist-update.timer
    run_cmd sudo systemctl stop dnscrypt-proxy
    run_cmd sudo systemctl stop dnsmasq

    # Remove Files/Links
    remove_symlink_or_file "$TIMER_DEST" "sudo"
    remove_symlink_or_file "$SERVICE_DEST" "sudo"
    remove_symlink_or_file "$BIN_DIR/dns-blocklist-update.sh" "sudo"
    remove_symlink_or_file "/etc/dns-blocklists.conf" "sudo"
    
    # Locate dnscrypt config
    if [ -d "/etc/dnscrypt-proxy" ]; then
        remove_symlink_or_file "/etc/dnscrypt-proxy/dnscrypt-proxy.toml" "sudo"
    else
        remove_symlink_or_file "/etc/dnscrypt-proxy.toml" "sudo"
    fi
    
    remove_symlink_or_file "/etc/dnsmasq.conf" "sudo"
    
    # Clean up generated blocklist
    if [ -f "/etc/dnsmasq.d/hagezi.conf" ]; then
         echo "Removing generated blocklist..."
         run_cmd sudo rm "/etc/dnsmasq.d/hagezi.conf"
    fi

    run_cmd sudo systemctl daemon-reload

    echo "Uninstallation complete. Note: 'dnscrypt-proxy' and 'dnsmasq' packages were NOT removed."

else
    echo "Unsupported OS."
    exit 1
fi

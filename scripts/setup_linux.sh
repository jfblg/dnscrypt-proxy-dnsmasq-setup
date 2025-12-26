#!/bin/bash

# setup_linux.sh
# Installs and configures dnscrypt-proxy and dnsmasq on Linux (Symlink version)

set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN_DIR="/usr/local/bin"
ETC_DNSMASQ="/etc/dnsmasq.d"
ETC_DNSCRYPT="/etc/dnscrypt-proxy"

DRY_RUN=false

# Check for --dry-run argument
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

# Detect Package Manager
if command -v apt-get &> /dev/null; then
    PKG_MANAGER="apt-get"
    INSTALL_CMD="apt-get install -y"
elif command -v pacman &> /dev/null; then
    PKG_MANAGER="pacman"
    INSTALL_CMD="pacman -S --noconfirm"
elif command -v dnf &> /dev/null; then
    PKG_MANAGER="dnf"
    INSTALL_CMD="dnf install -y"
else
    echo "Error: Supported package manager not found."
    exit 1
fi

# 1. Install packages
echo "Installing dnscrypt-proxy and dnsmasq..."
run_cmd sudo $INSTALL_CMD dnscrypt-proxy dnsmasq

# Helper for symlinking with sudo
safe_symlink() {
    local src="$1"
    local dest="$2"
    
    echo "Linking $src -> $dest"
    
    if [ -e "$dest" ] || [ -L "$dest" ]; then
        if [ "$(readlink "$dest")" == "$src" ]; then
            echo "  Link already correct."
            return
        fi
        echo "  Backing up existing $dest to $dest.bak"
        run_cmd sudo mv "$dest" "$dest.bak"
    fi

    local dir=$(dirname "$dest")
    if [ ! -d "$dir" ]; then
         run_cmd sudo mkdir -p "$dir"
    fi

    run_cmd sudo ln -sf "$src" "$dest"
}

# 2. Configure dnscrypt-proxy
echo "Configuring dnscrypt-proxy..."
if [ ! -d "$ETC_DNSCRYPT" ] && [ -f "/etc/dnscrypt-proxy.toml" ]; then
    ETC_DNSCRYPT="/etc"
fi
safe_symlink "$REPO_ROOT/config/dnscrypt-proxy.toml" "$ETC_DNSCRYPT/dnscrypt-proxy.toml"

# 3. Configure dnsmasq
echo "Configuring dnsmasq..."
safe_symlink "$REPO_ROOT/config/dnsmasq.conf" "/etc/dnsmasq.conf"
run_cmd sudo mkdir -p "$ETC_DNSMASQ"

# 4. Install update script and config
echo "Installing update script..."
safe_symlink "$REPO_ROOT/config/blocklists.conf" "/etc/dns-blocklists.conf"
safe_symlink "$REPO_ROOT/scripts/update-blocklists.sh" "$BIN_DIR/dns-blocklist-update.sh"
if [ "$DRY_RUN" = false ]; then
    chmod +x "$REPO_ROOT/scripts/update-blocklists.sh"
fi

# 5. Setup Systemd Timer
echo "Setting up Systemd timer..."
SERVICE_DEST="/etc/systemd/system/dns-blocklist-update.service"
TIMER_DEST="/etc/systemd/system/dns-blocklist-update.timer"

safe_symlink "$REPO_ROOT/services/dns-blocklist-update.service" "$SERVICE_DEST"
safe_symlink "$REPO_ROOT/services/dns-blocklist-update.timer" "$TIMER_DEST"

run_cmd sudo systemctl daemon-reload
run_cmd sudo systemctl enable dns-blocklist-update.timer
run_cmd sudo systemctl start dns-blocklist-update.timer

# 6. Handle systemd-resolved conflict
if systemctl is-active --quiet systemd-resolved; then
     echo "NOTE: Ensure systemd-resolved is not using port 53 (DNSStubListener=no)."
fi

# 7. Start Services
echo "Starting DNS services..."
run_cmd sudo systemctl enable dnscrypt-proxy
run_cmd sudo systemctl restart dnscrypt-proxy
run_cmd sudo systemctl enable dnsmasq
run_cmd sudo systemctl restart dnsmasq

# 8. Initial Update
echo "Running initial blocklist update..."
run_cmd sudo "$BIN_DIR/dns-blocklist-update.sh" -c "/etc/dns-blocklists.conf" -o "$ETC_DNSMASQ/hagezi.conf"

echo "Setup complete! (Dry Run: $DRY_RUN)"
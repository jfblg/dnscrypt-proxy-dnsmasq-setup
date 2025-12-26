#!/bin/bash

# setup_macos.sh
# Installs and configures dnscrypt-proxy and dnsmasq on macOS (Symlink version)

set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BREW_PREFIX=$(brew --prefix)
ETC_DIR="$BREW_PREFIX/etc"
BIN_DIR="/usr/local/bin"

DRY_RUN=false

# Check for --dry-run argument
for arg in "$@"; do
    if [ "$arg" == "--dry-run" ]; then
        DRY_RUN=true
        echo ">>> DRY RUN MODE ACTIVATED: No changes will be made."
    fi
done

# Helper function to execute commands respecting Dry Run
run_cmd() {
    if [ "$DRY_RUN" = true ]; then
        echo "[DRY RUN] $*"
    else
        "$@"
    fi
}

echo "Detected Homebrew prefix: $BREW_PREFIX"

# 1. Install packages
echo "Checking packages..."
if ! brew list dnscrypt-proxy &>/dev/null; then
    echo "Installing dnscrypt-proxy..."
    run_cmd brew install dnscrypt-proxy
else
    echo "dnscrypt-proxy already installed."
fi

if ! brew list dnsmasq &>/dev/null; then
    echo "Installing dnsmasq..."
    run_cmd brew install dnsmasq
else
    echo "dnsmasq already installed."
fi

# Function to safely symlink
safe_symlink() {
    local src="$1"
    local dest="$2"
    local sudo_cmd="$3" # "sudo" or empty

    echo "Linking $src -> $dest"
    
    # Check if destination exists
    if [ -e "$dest" ] || [ -L "$dest" ]; then
        # Check if it's already the correct link
        if [ "$(readlink "$dest")" == "$src" ]; then
            echo "  Link already correct."
            return
        fi
        
        echo "  Backing up existing $dest to $dest.bak"
        $sudo_cmd run_cmd mv "$dest" "$dest.bak"
    fi

    # Create directory if needed
    local dir=$(dirname "$dest")
    if [ ! -d "$dir" ]; then
         $sudo_cmd run_cmd mkdir -p "$dir"
    fi

    $sudo_cmd run_cmd ln -sf "$src" "$dest"
}

# 2. Configure dnscrypt-proxy
echo "Configuring dnscrypt-proxy..."
safe_symlink "$REPO_ROOT/config/dnscrypt-proxy.toml" "$ETC_DIR/dnscrypt-proxy.toml" ""

# 3. Configure dnsmasq
echo "Configuring dnsmasq..."
safe_symlink "$REPO_ROOT/config/dnsmasq.conf" "$ETC_DIR/dnsmasq.conf" ""
run_cmd mkdir -p "$ETC_DIR/dnsmasq.d"

# 4. Install update script and config
echo "Installing update script and config..."
safe_symlink "$REPO_ROOT/config/blocklists.conf" "$ETC_DIR/dns-blocklists.conf" ""
safe_symlink "$REPO_ROOT/scripts/update-blocklists.sh" "$BIN_DIR/dns-blocklist-update.sh" "sudo"
# Ensure executable permission on source
if [ "$DRY_RUN" = false ]; then
    chmod +x "$REPO_ROOT/scripts/update-blocklists.sh"
else
    echo "[DRY RUN] chmod +x $REPO_ROOT/scripts/update-blocklists.sh"
fi


# 5. Setup Launchd
echo "Setting up Launchd service..."
PLIST_SOURCE="$REPO_ROOT/services/com.user.dns-blocklist-update.plist"
PLIST_DEST="/Library/LaunchDaemons/com.user.dns-blocklist-update.plist"

safe_symlink "$PLIST_SOURCE" "$PLIST_DEST" "sudo"

# Fix ownership of the linked plist source file? 
# Launchd might complain if the plist is owned by user but trying to run as root daemon?
# Actually, symlinking into LaunchDaemons is tricky because of permissions. 
# The SYMLINK itself will be owned by root (created by sudo ln), but it points to a user file.
# macOS might refuse to load it if the target is writable by non-root (security feature).
# For this specific case, we will chown the SOURCE file in the repo to root:wheel if we are not in dry run?
# No, that breaks git.
# Compromise: We keep the file in repo user-owned. If launchd refuses, we warn.
# (Usually, standard macOS security allows symlinks if the directory is secure, but let's see).

echo "Loading update service..."
if [ "$DRY_RUN" = false ]; then
    sudo launchctl unload "$PLIST_DEST" 2>/dev/null || true
    sudo launchctl load "$PLIST_DEST"
else
    echo "[DRY RUN] sudo launchctl unload $PLIST_DEST"
    echo "[DRY RUN] sudo launchctl load $PLIST_DEST"
fi

# 6. Start/Restart services
echo "Starting DNS services..."
run_cmd sudo brew services restart dnscrypt-proxy
run_cmd sudo brew services restart dnsmasq

# 7. Initial Run
echo "Running initial blocklist update..."
run_cmd sudo "$BIN_DIR/dns-blocklist-update.sh" -c "$ETC_DIR/dns-blocklists.conf" -o "$ETC_DIR/dnsmasq.d/hagezi.conf"

echo "Setup complete! (Dry Run: $DRY_RUN)"
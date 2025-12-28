# DNS Privacy Setup (dnscrypt-proxy + dnsmasq)

A collection of scripts to automate the installation and configuration of **dnscrypt-proxy** and **dnsmasq** on macOS and Linux. This setup improves DNS privacy and security by encrypting DNS queries and blocking unwanted domains (ads, trackers, malware) using [Hagezi's DNS Blocklists](https://github.com/hagezi/dns-blocklists).

This project is inspired by the excellent [macOS Security and Privacy Guide](https://github.com/drduh/macOS-Security-and-Privacy-Guide) by drduh.

## How it Works

1.  **dnsmasq** runs on port 53 (standard DNS port). It handles local caching and checks the blocklist.
2.  If a domain is blocked, it returns `0.0.0.0` (NXDOMAIN equivalent behavior with Hagezi list).
3.  If allowed and not in cache, it forwards the query to **dnscrypt-proxy** on port 5353.
4.  **dnscrypt-proxy** encrypts the query and sends it to a secure upstream resolver.

## Features

*   **Automated Installation:** Installs required packages using Homebrew (macOS) or native package managers (Linux).
*   **Encrypted DNS:** Configures `dnscrypt-proxy` to use secure, encrypted DNS resolvers (DoH/dnscrypt).
*   **Ad Blocking:** Configures `dnsmasq` to act as a local DNS cache and blocklist enforcer.
*   **Automatic Updates:** Sets up a background job (Launchd on macOS, Systemd Timer on Linux) to automatically download and update blocklists daily.
*   **Modular Configuration:** Easy to customize blocklist sources and DNS settings.

## Prerequisites

*   **macOS:** [Homebrew](https://brew.sh/) must be installed.
*   **Linux:** `systemd` and a supported package manager (`apt`, `pacman`, `dnf`).

## Installation

1.  Clone this repository:
    ```bash
    git clone https://github.com/yourusername/dnscrypt-proxy-dnsmasq-setup.git
    cd dnscrypt-proxy-dnsmasq-setup
    ```

2.  Run the installation script:
    ```bash
    ./scripts/install.sh
    ```

    *Note: The script uses symlinks to the repository files, allowing you to update configurations via git. It may ask for `sudo` password to install packages and configure services.*

### Dry Run (Preview Changes)

To see what the script will do without making any changes, use the `--dry-run` flag:
```bash
./scripts/install.sh --dry-run
```

## Uninstallation

To remove the symlinks and restore any backed-up configuration files:
```bash
./scripts/uninstall.sh
```

You can also preview the uninstallation process:
```bash
./scripts/uninstall.sh --dry-run
```

## Configuration

### Blocklists

The blocklist configuration is stored in:
*   **macOS:** `/usr/local/etc/dns-blocklists.conf` (or `/opt/homebrew/etc/dns-blocklists.conf`)
*   **Linux:** `/etc/dns-blocklists.conf`

By default, the **Hagezi Multi PRO** list is used. To change the protection level or use a different list:

1.  Open the configuration file.
2.  Uncomment the desired `URL` variable.
3.  Comment out the existing one.
4.  Run the update script manually to apply changes immediately:
    ```bash
    # macOS
    sudo /usr/local/bin/dns-blocklist-update.sh -c /usr/local/etc/dns-blocklists.conf -o /usr/local/etc/dnsmasq.d/hagezi.conf
    
    # Linux
    sudo /usr/local/bin/dns-blocklist-update.sh -c /etc/dns-blocklists.conf -o /etc/dnsmasq.d/hagezi.conf
    ```

### DNS Settings

*   **dnscrypt-proxy:** Configured to listen on `127.0.0.1:5353`.
    *   Config file: `/usr/local/etc/dnscrypt-proxy.toml` (macOS) or `/etc/dnscrypt-proxy/dnscrypt-proxy.toml` (Linux).
*   **dnsmasq:** Configured to listen on `127.0.0.1:53` and forward queries to `dnscrypt-proxy`.
    *   Config file: `/usr/local/etc/dnsmasq.conf` (macOS) or `/etc/dnsmasq.conf` (Linux).

### Setting 127.0.0.1 as System DNS

After installation, you must point your operating system to use the local `dnsmasq` instance as its DNS resolver.

#### macOS
1.  Open **System Settings** > **Network**.
2.  Select your active connection (e.g., Wi-Fi) and click **Details...**.
3.  Go to the **DNS** tab.
4.  Click the **+** button and add `127.0.0.1`.
5.  Remove any other DNS servers listed.

Alternatively, via CLI:
```bash
sudo networksetup -setdnsservers Wi-Fi 127.0.0.1
```

#### Linux
Most modern distributions use `systemd-resolved` or `NetworkManager`.

**Option A: Edit /etc/resolv.conf** (Manual/Static)
Ensure `/etc/resolv.conf` contains:
```text
nameserver 127.0.0.1
```

**Option B: NetworkManager**
```bash
nmcli device show | grep IP4.DNS
nmcli con mod <connection_name> ipv4.dns "127.0.0.1"
nmcli con up <connection_name>
```

**Option C: systemd-resolved**
If you want to keep `systemd-resolved` running, set `DNSStubListener=no` in `/etc/systemd/resolved.conf` to free port 53, and set your global DNS to `127.0.0.1`.

## Managing Services

Here are the commands to manually start, stop, or restart the services.

### macOS (Homebrew Services)
Since `dnsmasq` runs on port 53, it operates as a root service.

**Start:**
```bash
sudo brew services start dnscrypt-proxy
sudo brew services start dnsmasq
```

**Stop:**
```bash
sudo brew services stop dnscrypt-proxy
sudo brew services stop dnsmasq
```

**Restart:**
```bash
sudo brew services restart dnscrypt-proxy
sudo brew services restart dnsmasq
```

### Linux (Systemd)

**Start:**
```bash
sudo systemctl start dnscrypt-proxy
sudo systemctl start dnsmasq
```

**Stop:**
```bash
sudo systemctl stop dnscrypt-proxy
sudo systemctl stop dnsmasq
```

**Restart:**
```bash
sudo systemctl restart dnscrypt-proxy
sudo systemctl restart dnsmasq
```

## License

MIT License. See [LICENSE](LICENSE) for details.

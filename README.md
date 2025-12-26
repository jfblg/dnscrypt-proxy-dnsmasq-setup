# DNS Privacy Setup (dnscrypt-proxy + dnsmasq)

A collection of scripts to automate the installation and configuration of **dnscrypt-proxy** and **dnsmasq** on macOS and Linux. This setup improves DNS privacy and security by encrypting DNS queries and blocking unwanted domains (ads, trackers, malware) using [Hagezi's DNS Blocklists](https://github.com/hagezi/dns-blocklists).

This project is inspired by the excellent [macOS Security and Privacy Guide](https://github.com/drduh/macOS-Security-and-Privacy-Guide) by drduh.

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

## How it Works

1.  **dnsmasq** runs on port 53 (standard DNS port). It handles local caching and checks the blocklist.
2.  If a domain is blocked, it returns `0.0.0.0` (NXDOMAIN equivalent behavior with Hagezi list).
3.  If allowed and not in cache, it forwards the query to **dnscrypt-proxy** on port 5353.
4.  **dnscrypt-proxy** encrypts the query and sends it to a secure upstream resolver.

## License

MIT License. See [LICENSE](LICENSE) for details.

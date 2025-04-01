# Generic Webhook Service for Automated Static Site Builds

This Perl-based webhook service listens for GitHub push events, validates them, and triggers automated builds for static sites hosted on an OpenBSD server. It’s designed to be flexible, supporting any static site generator that can be built via a shell script.

## Overview

The service runs as a daemon on a configurable port (default 8080), responds immediately to GitHub with a `200 OK` to acknowledge receipt, and forks a child process to pull the latest Git changes and execute a custom build script. It uses `doas` for secure user switching and supports multiple sites via a configuration file.

## Features

- Listens on a specified port (default 8080) for GitHub webhook POST requests.
- Validates payloads with `X-Hub-Signature-256` HMAC SHA256.
- Pulls latest Git commits before building.
- Executes custom build scripts in specified working directories.
- Runs as a daemon with OpenBSD `rc.d` integration.
- Logs all actions to a configurable log file (default `/var/log/webhook.log`).

## Requirements

- OpenBSD (tested on 7.x).
- Perl (included in OpenBSD base, with `Digest::SHA`).
- Git installed and configured for the build user.
- `doas` configured for privilege escalation.
- Network access to the chosen port (firewall rule required).

## Installation

1. **Place the Script**
    Save the webhook script as `/usr/local/bin/webhook.pl`:
        /usr/local/bin/webhook.pl
    Set permissions:
        chown root:wheel /usr/local/bin/webhook.pl
        chmod 755 /usr/local/bin/webhook.pl

2. **Configure Sites**
    Create `/etc/webhook.conf` with site details:
        <webhook-secret> <build-user> <repo-path> <build-script-path>
    - Format: `secret user workdir build_command`
    - `secret`: GitHub webhook secret (e.g., `my-secret-key`).
    - `user`: User to run the build (e.g., `www` or a custom user).
    - `workdir`: Directory containing the Git repo (e.g., `/var/www/htdocs/site`).
    - `build_command`: Script to build the site (e.g., `/usr/local/bin/build-site.sh`).
    Set permissions:
        chown root:<build-user> /etc/webhook.conf
        chmod 640 /etc/webhook.conf

3. **Set Up `doas`**
    Edit `/etc/doas.conf`:
        permit nopass root as <build-user> cmd sh args -c "cd <repo-path> && git pull && <build-script-path>"
    Replace `<build-user>`, `<repo-path>`, and `<build-script-path>` with your values.
    Set permissions:
        chown root:wheel /etc/doas.conf
        chmod 600 /etc/doas.conf

4. **Configure the Service**
    Create `/etc/rc.d/webhook`:
        #!/bin/sh
        daemon="/usr/local/bin/webhook.pl"
        daemon_user="root"
        
        . /etc/rc.d/rc.subr
        
        rc_cmd $1
    Set permissions:
        chmod +x /etc/rc.d/webhook
    Enable on boot:
        rcctl enable webhook

5. **Open Firewall**
    Add to `/etc/pf.conf` (adjust port if changed):
        ext_if = "vio0"  # Replace with your interface
        pass in on $ext_if proto tcp to port 8080
    Reload:
        pfctl -f /etc/pf.conf

6. **Set Up Git**
    Ensure the build user has Git access:
        su - <build-user>
        cd <repo-path>
        git clone <your-repo-url> .  # Or use SSH
    Configure credentials (HTTPS) or SSH keys as needed.

7. **Start the Service**
    Start manually:
        rcctl start webhook
    Check it’s running:
        ps aux | grep webhook.pl
    Verify logs:
        tail -f /var/log/webhook.log

## Usage

1. **GitHub Webhook Setup**
    - Go to your GitHub repo’s settings.
    - Navigate to `Settings > Webhooks > Add webhook`.
    - Set:
        - Payload URL: `http://<your-domain>:<port>` (e.g., `http://example.com:8080`)
        - Content type: `application/json` (recommended)
        - Secret: `<webhook-secret>` (must match `/etc/webhook.conf`)
        - Events: Select “Just the push event”
    - Save and test with a commit.

2. **Triggering a Build**
    Push a commit to the repo:
        git push origin main
    The service will:
    - Receive the webhook.
    - Respond with `200 OK` instantly.
    - Pull the latest changes in the background.
    - Run the build script.
    Check logs:
        tail -f /var/log/webhook.log

## Troubleshooting

- **Service Not Starting**
    Run manually:
        /usr/local/bin/webhook.pl
    Check `/var/log/messages` for errors.

- **Git Pull Fails**
    Test as the build user:
        su - <build-user>
        cd <repo-path>
        git pull
    Fix permissions or credentials if needed.

- **GitHub Delivery Fails**
    Check “Recent Deliveries” in webhook settings for response details.
    Verify port is open externally:
        curl -v http://<your-domain>:<port>

- **Logs Silent**
    Ensure permissions:
        chown root:<build-user> /var/log/webhook.log
        chmod 664 /var/log/webhook.log

## Example Log Output

    2025-04-01 14:00:00 - Headers read in 0 seconds
    2025-04-01 14:00:00 - Full request headers: ...
    2025-04-01 14:00:00 - Response sent to client in 0 seconds
    2025-04-01 14:00:00 - Payload read, length=10428
    2025-04-01 14:00:00 - Signature match for secret=<webhook-secret>, user=<build-user>, workdir=<repo-path>, cmd=<build-script-path>
    2025-04-01 14:00:01 - Build succeeded for <build-user> in <repo-path>

## Customization

- **Change Port**: Edit `LocalPort => 8080` in the script and update firewall rules and GitHub webhook URL.
- **Multiple Sites**: Add more lines to `/etc/webhook.conf` and corresponding `doas` entries.
- **Debug Mode**: Run `DEBUG=1 /usr/local/bin/webhook.pl` to avoid daemonizing for testing.

## Notes

- The script assumes `git` and the build script are executable and correctly configured in the `workdir`.
- Adjust paths, users, and secrets to match your environment.

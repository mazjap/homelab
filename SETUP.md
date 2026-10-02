# Homelab Setup Guide

Complete setup instructions for Raspberry Pi 5 (8GB) homelab infrastructure.

## Hardware Requirements

- Raspberry Pi 5
- 128GB+ microSD card
- Ethernet connection
- Official Raspberry Pi 5 power supply

## Network Configuration

- **Router IP:** 192.168.0.1
- **Pi Static IP:** 192.168.0.40 (set via DHCP reservation in router)
- **Subnet:** 192.168.0.0/24
- **Docker Network:** 10.2.0.0/24
- **VPN Network:** 10.8.0.0/24

## Initial Pi Setup

### 1. Flash SD Card

Use Raspberry Pi Imager:
1. **Device:** Raspberry Pi 5
2. **OS:** Raspberry Pi OS Lite (64-bit)
3. **Storage:** Your 128GB SD card
4. **Configure:**
   - Hostname: `pistack`
   - Username: `jman`
   - Password: (your choice)
   - WiFi: (optional, ethernet recommended)
   - Locale: America/Denver, US keyboard
   - ✅ Enable SSH

### 2. First Boot
```bash
# SSH into Pi
ssh jman@pistack.local
# Or: ssh jman@192.168.0.40

# Update system
sudo apt update && sudo apt upgrade -y

# (Optional) Install neovim
sudo apt install -y neovim

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker jman

# Reboot
sudo reboot
```

### 3. Configure Neovim (Optional)
```bash
mkdir -p ~/.config/nvim
nvim ~/.config/nvim/init.lua
```

Add:
```lua
-- OSC 52 clipboard support for SSH
-- Allows for clipboard shaing between host and remote device
vim.g.clipboard = {
  name = 'OSC 52',
  copy = {
    ['+'] = require('vim.ui.clipboard.osc52').copy('+'),
    ['*'] = require('vim.ui.clipboard.osc52').copy('*'),
  },
  paste = {
    ['+'] = require('vim.ui.clipboard.osc52').paste('+'),
    ['*'] = require('vim.ui.clipboard.osc52').paste('*'),
  },
}
vim.opt.clipboard = 'unnamedplus'
vim.opt.number = true
vim.opt.relativenumber = true
```

## Service Stack Setup

### Create Project Directory
```bash
git clone https://github.com/mazjap/homelab.git
cd homelab
```

### Create Environment File
```bash
cp .env.example .env
```

And replace with your own values.

Note that these environment variables need special attention:

```bash
# Paperless - Generate a random 32 character hex string with: openssl rand -hex 32
PAPERLESS_SECRET_KEY=01234567890abcdef...

# WireGuard - Generated later in setup hash with: docker run -it ghcr.io/wg-easy/wg-easy wgpw 'YourPassword'
# IMPORTANT: Escape $ as $$ in the hash (e.g., $2a becomes $$2a)
WIREGUARD_PASSWORD_HASH=$$2a$$12$$YourHashHere

# Pihole password - Set later in setup via: docker exec pihole pihole setpassword

# Pihole api key - Set later in setup via web UI
PIHOLE_API_KEY=RXhhbXBsZSBvZiB3aGF0IGEgcGlob2xlIGFwaSBrZXkgbWlnaHQgbG9vayBsaWtl=

# Portainer - Set later in setup via web UI
PORTAINER_API_KEY=RXhhbXBsZSBvZiB3aGF0IGEgcGlob2xlIGFwaSBrZXkgbWlnaHQgbG9vayBsaWtl=

# 4play - Letters and digits only (it goes in a URL and in 4get's generated PHP config)
# Generate with: tr -dc A-Za-z0-9 </dev/urandom | head -c 40
FPLAY_PASSWORD=YourLettersAndDigitsOnlyPassword

# Auto-update - Where the weekly update report is emailed
UPDATE_EMAIL=your-email@gmail.com
```

All other environment variables can be set now.

Protect it:
```bash
chmod 600 .env
```

### Start Services
```bash
# Install the 4play render server's dependencies (otherwise fourplay restart-loops)
docker run --rm -u 1000:1000 -e HOME=/tmp -v "$PWD/4play:/app" -w /app node:26-alpine npm install

docker compose up -d
```

### Check Everything Started
```bash
docker ps
# Should show all containers running
```

## Service Configuration

### Service IP Addresses and Ports

| Service             | Docker IP | External Port | Internal Port | Access URL               |
|---------------------|-----------|---------------|---------------|--------------------------|
| Unbound             | 10.2.0.2  | 5335          | 53            | N/A (DNS only)           |
| Pihole             | 10.2.0.3  | 53, 8082      | 53, 80        | http://pihole.home/admin |
| WireGuard           | 10.2.0.4  | 51820, 51821  | 51820, 51821  | http://vpn.home          |
| Homepage            | 10.2.0.5  | 3000          | 3000          | http://homepage.home     |
| Glances             | 10.2.0.7  | 61208         | 61208         | http://glances.home      |
| Portainer           | 10.2.0.8  | 9000          | 9000          | http://portainer.home    |
| Uptime Kuma         | 10.2.0.9  | 3001          | 3001          | http://uptime.home       |
| Nginx Proxy Manager | 10.2.0.10 | 80, 81, 443   | 80, 81, 443   | http://nginx.home        |
| 4get                | 10.2.0.11 | 8282          | 80            | http://4get.home         |
| Gitea               | 10.2.0.12 | 3030, 2222    | 3000, 22      | http://gitea.home        |
| Linkding            | 10.2.0.14 | 9090          | 9090          | http://linkding.home     |
| Paperless Redis     | 10.2.0.15 | -             | 6379          | N/A (internal)           |
| Paperless DB        | 10.2.0.16 | -             | 5432          | N/A (internal)           |
| Paperless           | 10.2.0.17 | 8000          | 8000          | http://paperless.home    |
| Immich              | 10.2.0.18 | 2283          | 2283          | http://192.168.0.40:2283 |
| Immich Microservices | 10.2.0.19 | -            | -             | N/A (internal)           |
| Immich Redis        | 10.2.0.21 | -             | 6379          | N/A (internal)           |
| Immich DB           | 10.2.0.22 | -             | 5432          | N/A (internal)           |
| RomM                | 10.2.0.23 | 8080          | 8080          | http://192.168.0.40:8080 |
| RomM DB             | 10.2.0.24 | -             | 3306          | N/A (internal)           |
| 4play               | 10.2.0.25 | 127.0.0.1:3131 | 3030, 3000   | N/A (see 4play Setup)    |

### Pihole Setup

1. Access: http://192.168.0.40:8082/admin
2. Set password:
```bash
   docker exec pihole pihole setpassword 'YourPassword123'
```
3. Configure:
   - Settings -> DNS -> Upstream DNS: Disable all
   - Settings -> DNS -> Custom DNS servers: Add `10.2.0.2#53`
   - Settings -> DNS (Expert mode on) -> Interface: Permit all origins
4. Generate app password:
   - Settings -> Web Interface/API (Expert mode on) -> Advanced Settings -> Configure app password
   - Add to `.env` as `PIHOLE_API_KEY`

### Pihole Local DNS Records

Go to Pihole -> Local DNS -> DNS Records, add:
```
homepage.home      192.168.0.40
page.home          192.168.0.40
pihole.home        192.168.0.40
4get.home          192.168.0.40
search.home        192.168.0.40
uptime.home        192.168.0.40
vpn.home           192.168.0.40
wireguard.home     192.168.0.40
gitea.home         192.168.0.40
linkding.home      192.168.0.40
paperless.home     192.168.0.40
nginx.home         192.168.0.40
portainer.home     192.168.0.40
glances.home       192.168.0.40
nginx.home         192.168.0.40
```

### Router Configuration

1. Set primary DNS to `192.168.0.40`
2. Remove secondary DNS (important!)
3. Port forward for WireGuard:
   - External: 51820/UDP
   - Internal: 192.168.0.40:51820

### WireGuard Setup

**Generate Password Hash:**
```bash
docker run -it ghcr.io/wg-easy/wg-easy wgpw 'YourPasswordHere'
# Copy output, add to .env with $$ escaping
docker compose restart wg-easy
```

1. Access: http://192.168.0.40:51821
2. Login with password
3. Create VPN clients as needed
4. Scan QR codes with WireGuard mobile app

### Nginx Proxy Manager Setup

1. Access: http://192.168.0.40:81
2. Create account
3. Add proxy hosts for each service (see table above)
   - Use Docker internal IPs (10.2.0.x)
   - Use internal ports
   - Example: `pihole.home` -> `http://10.2.0.3:80`

### Gitea Setup

1. Access: http://gitea.home (or http://192.168.0.40:3030)
2. Initial configuration:
   - Database: SQLite3
   - SSH Port: `2222`
   - Domain: `gitea.home`
   - Base URL: `http://gitea.home/`
3. Create admin account
4. Add SSH key:
   - Settings -> SSH/GPG Keys
   - Add your public key

**SSH Config:**
```bash
nvim ~/.ssh/config
```

Add:
```
Host gitea.home
    HostName localhost  # or 192.168.0.40
    Port 2222
    User git
```

### 4get Setup

4get requires manual compilation for ARM64. Clone the fork, which already has
the ARM64 Dockerfile, the curl-impersonate build files, and CORS headers on
`api/v1/ac.php` for the Homepage search bar. Clone it next to `pistack`, since
`auto-update.sh` expects `~/4get`:
```bash
cd ~
git clone https://github.com/mazjap/4get.git
cd 4get
```

The 4get Dockerfile builds on a local curl-impersonate image, because upstream
curl-impersonate doesn't publish one for arm64. Build it once (~15 min on a Pi 5):
```bash
cd curl-impersonate-build
docker build --platform linux/arm64 -t curl-impersonate-ff-arm64 -f Dockerfile.alpine .
cd ..
```

Build 4get. The label records which commit the image was built from, so
`auto-update.sh` knows when it needs a rebuild:
```bash
docker build --platform linux/arm64 --label "fourget.commit=$(git rev-parse HEAD)" -t 4get-arm:latest .
cd ~/pistack
docker compose up -d fourget
```

4get's settings come from the `FOURGET_*` environment variables in
`docker-compose.yml` (the image generates `data/config.php` at startup), so
don't edit `data/config.php` directly.

**Set up Git remotes: (optional)**
```bash
cd ~/4get
git remote add upstream https://git.lolcat.ca/lolcat/4get.git
git remote add origin git@gitea.home:jman/4get.git

# Always keep the ARM64 Dockerfile when merging upstream changes
echo "Dockerfile merge=ours" >> .git/info/attributes
git config merge.ours.driver true

git push -u origin main
```

### 4play Setup (Google search in 4get)

4get's Google scraper loads Google in a real Firefox, controlled through the
[4play](https://git.lolcat.ca/lolcat/4play) extension:

```
4get ──HTTP :3000──> fourplay container ──WebSocket :3030 (host 127.0.0.1:3131)──> Firefox + 4play
```

Firefox runs on the Pi itself (not in Docker) inside a headless labwc session
that renders on the Pi's GPU, so no monitor is needed and Google sees real
hardware graphics. It runs as a dedicated `4player` user with a clean profile.
The config files are in `4play/host/`.

**1. Install packages:**
```bash
sudo apt install -y --no-install-recommends labwc wayvnc grim wlr-randr xz-utils \
    libasound2t64 libatk1.0-0t64 libcairo-gobject2 libdbus-1-3 libevent-2.1-7t64 \
    libgdk-pixbuf-2.0-0 libgtk-3-0t64 libpango-1.0-0 libx11-xcb1 libxcomposite1 \
    libxdamage1 libxrandr2 libxtst6 libpci3 libegl1 libgl1-mesa-dri libgbm1 \
    fontconfig fonts-dejavu fonts-liberation2 fonts-noto-core fonts-noto-color-emoji

# The wayvnc package enables a system-wide VNC server that listens on your LAN.
# We run our own localhost-only one instead.
sudo systemctl disable --now wayvnc.service wayvnc-control.service
```

**2. Create the user and install Firefox** (Mozilla's official ARM64 build,
which updates itself):
```bash
sudo useradd --system --create-home --home-dir /home/4player \
    --shell /usr/sbin/nologin --groups video,render 4player
sudo chmod 750 /home/4player

cd /tmp
curl -L -o firefox.tar.xz "https://download.mozilla.org/?product=firefox-latest-ssl&os=linux64-aarch64&lang=en-US"
sudo tar -xJf firefox.tar.xz -C /home/4player
sudo mv /home/4player/firefox /home/4player/app
rm firefox.tar.xz
```

Tip: to keep Firefox on an SSD instead of the SD card, use an SSD path for
`--home-dir` and in the commands below. The service files use `$HOME`.

**3. Install the config files:**
```bash
cd ~/pistack/4play/host
sudo install -D -m 644 policies.json   /home/4player/app/distribution/policies.json
sudo install -D -m 644 user.js         /home/4player/profile/user.js
sudo install -D -m 644 labwc-autostart /home/4player/.config/labwc/autostart
sudo chown -R 4player:4player /home/4player

sudo cp 4player-desktop.service 4player-vnc.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now 4player-desktop.service
```

- `policies.json` force-installs 4play and turns off telemetry, password saving,
  and first-run pages.
- `user.js` turns off history and session restore. Don't turn on "Always use
  private browsing mode": 4play needs containers, which that disables.
- `4player-vnc.service` is intentionally not enabled; start it only when you
  need to see the browser.

**4. Point the extension at the render server.** 4play stores its settings
inside Firefox, and they can only be changed from its toolbar popup, so you
connect over VNC once.

On the Pi, start VNC (it only listens on the Pi's localhost):
```bash
sudo systemctl start 4player-vnc
```

On your Mac, install a viewer (macOS Screen Sharing can't connect to wayvnc) and
open an SSH tunnel. Leave the tunnel running; it shows no output:
```bash
brew install --cask tigervnc-viewer
ssh -N -L 5900:127.0.0.1:5900 jman@192.168.0.40
```

Open TigerVNC Viewer and connect to `localhost:5900`. The "unencrypted" warning
is fine, since the SSH tunnel encrypts it. Then, in Firefox:
1. Click the puzzle-piece icon, then 4play.
2. Set the URL to `ws://127.0.0.1:3131/<FPLAY_PASSWORD from .env>` (port 3131, not
   the 3030 from the 4play docs, since Gitea uses 3030).
3. Set the timeout to `30000`.
4. The icon turns from red to green within about 30 seconds.
5. Optional: in a new tab, open `about:support` → Graphics. Compositing should
   say `WebRender` (not `WebRender (Software)`) and WebGL 1 Driver Renderer
   should mention `V3D`.

Close the viewer, stop the tunnel with Ctrl+C, and stop VNC:
```bash
sudo systemctl stop 4player-vnc
```

**5. Test:** search with the Google scraper in 4get. `docker logs fourplay`
should show `New browser instance connected` and a `Rendering ...` line per
search.

### Homepage Setup

Homepage should work immediately. Customize:
```bash
cd ~/pistack/homepage
```

Edit configuration files:
- `services.yaml` - Service tiles
- `widgets.yaml` - Info widgets
- `settings.yaml` - Theme, layout
- `bookmarks.yaml` - Quick links
- `custom.js` - Custom search bar with 4get autocomplete
- `custom.css` - Custom styles

Note: Homepage pulls secrets from `.env` through mappings defined in docker-compose.yml. If widgets aren't working, verify that the base secrets (PIHOLE_API_KEY, PORTAINER_API_KEY, etc.) are set correctly in `.env`.

### Linkding Setup

1. Access: http://linkding.home
2. Login with credentials from `.env`
3. Settings -> Integrations -> Generate API token
5. Install browser extension and configure with generated API token

### Paperless Setup

1. Create superuser:
```bash
   docker exec -it paperless python3 manage.py createsuperuser
```
2. Access: http://paperless.home
3. Login with credentials
4. Configure:
   - Create tags (Taxes, Medical, etc.)
   - Create document types
   - Set up correspondents

**Upload documents:**
- Web UI: Upload button
- Watch folder: Copy to `~/pistack/paperless/consume/`
- Mobile app: "Swift Paperless" on iOS

### Uptime Kuma Setup

1. Access: http://uptime.home
2. Create admin account
3. Add monitors for all services
4. Configure notifications (email, telegram, etc.)
5. Add a slug called status and add all monitors

### Portainer Setup

1. Access: http://192.168.0.40:9000
2. Create admin account
3. Connect to local Docker environment
4. Generate API key: Settings -> API tokens
5. Store in ~/.env (PORTAINER_API_KEY)
6. Restart homepage: `docker compose restart homepage`

## Automation

### Auto-Update Script

Script location: `~/pistack/auto-update.sh`

Features:
- Backs up configs before updating (keeps the last 7)
- Merges 4get from upstream, always keeping the ARM64 Dockerfile. If upstream
  changed their Dockerfile, the report says so, so you can review it.
- Rebuilds `4get-arm` whenever the image wasn't built from the repo's current
  commit, including after manual merges. A failed build reverts the merge.
- Pulls each image separately with retries, so one failed pull only skips that
  service
- Recreates only containers whose image or config changed, then checks that
  every service is running
- Sends one email: **Homelab Update Succeeded** or **Homelab Update Failed**,
  listing only what was updated (with versions where the image provides them)
  and what failed
- Logs everything else to `update.log` (trimmed to the last 10,000 lines)

Preview what would change without merging, rebuilding, or restarting anything
(this also sends a "[Dry run]" report):
```bash
~/pistack/auto-update.sh --dry-run
```

### Email Configuration
```bash
sudo apt install ssmtp mailutils -y
sudo nvim /etc/ssmtp/ssmtp.conf
```

Add:
```
root=your-email@gmail.com
mailhub=smtp.gmail.com:587
hostname=pistack
AuthUser=your-email@gmail.com
AuthPass=YourGmailAppPassword
UseSTARTTLS=YES
FromLineOverride=YES
```

**Generate Gmail App Password:**
1. Google Account -> Security -> 2-Step Verification -> App passwords
2. Create password for "Mail" on "Linux Computer"
3. Use 16-character password (remove spaces)

Test:
```bash
echo "Test from pistack" | mail -s "Test" your-email@gmail.com
```

### Cron Schedule
```bash
crontab -e
```

Add:
```
MAILTO=your-email@gmail.com
PATH=/usr/local/bin:/usr/bin:/bin

# Back up and auto-update homelab every Sunday at 3 AM
0 3 * * 0 /home/jman/pistack/auto-update.sh
```

The script emails its own report (to `UPDATE_EMAIL` in `.env`) and prints
nothing, so cron only emails you (via `MAILTO`) if the script itself can't run.
Don't add a second cron line to email the log.

## Backup & Restore

### Manual Backup
```bash
cd ~/pistack
tar -czf ~/homelab-backup-$(date +%Y%m%d).tar.gz \
    --exclude='*/logs' \
    --exclude='*/*.log' \
    .
```

### Restore
```bash
# On new Pi
scp backup.tar.gz jman@new-pi:~/
ssh jman@new-pi
tar -xzf homelab-backup.tar.gz -C ~/pistack
cd ~/pistack
cp .env.example .env  # Fill in secrets
docker compose up -d
```

## Maintenance

### Update All Services
Easiest is to run the auto-update script by hand (it prints its log as it goes):
```bash
~/pistack/auto-update.sh
```

Or manually. `4get-arm` is built locally, so its pull failure is expected:
```bash
cd ~/pistack
docker compose pull --ignore-pull-failures
docker compose up -d
docker image prune -f
```

### View Logs
```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f pihole

# Auto-update log
tail -f ~/pistack/update.log
```

### Restart Service
```bash
docker compose restart <service-name>
```

### Check Resource Usage
```bash
# System resources
docker stats

# Or visit Glances
http://192.168.0.40:61208
```

## Troubleshooting

### DNS Not Working
```bash
# Check Pihole
docker compose logs pihole

# Test DNS
nslookup google.com 192.168.0.40

# Clear DNS cache (on Mac)
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder
```

### Service Won't Start
```bash
# Check logs
docker compose logs <service>

# Check if port is taken
sudo netstat -tulpn | grep <port>

# Restart service
docker compose restart <service>
```

### Cannot Access .home Domains

1. Check Pi-hole has DNS records
2. Verify router DNS points to 192.168.0.40
3. Remove secondary DNS from router
4. Clear device/browser DNS cache
5. Try incognito window

### 4get Autocomplete Not Working

1. Check CORS headers in `api/v1/ac.php`
2. Rebuild: `docker build --platform linux/arm64 --label "fourget.commit=$(git rev-parse HEAD)" -t 4get-arm:latest .`
3. Check browser console for errors
4. Verify homepage/custom.js is loaded

### 4get Google Search Not Working

1. `docker logs fourplay` should show `New browser instance connected`. If it
   doesn't, check Firefox: `systemctl status 4player-desktop`.
2. If Firefox is running but never connects, check the 4play icon over VNC
   (see 4play Setup, step 4). It should be green, and the URL should use port
   3131 and the current `FPLAY_PASSWORD`.
3. "No browser available" errors from 4get mean the same thing as step 2.
4. Links that look like `/goto?url=...` and 404 mean the running 4get image is
   older than the repo. Compare `docker exec fourget wc -l scraper/google.php`
   with `wc -l ~/4get/scraper/google.php`, and rebuild if they differ.
5. The first search right after Firefox restarts can come back empty. Try again.

## Support

For issues or questions:
- Check logs: `docker compose logs <service>`
- Check auto-update log: `tail ~/pistack/update.log`
- Restart service: `docker compose restart <service>`
- Full restart: `docker compose down && docker compose up -d`

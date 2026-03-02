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
```

All other environment variables can be set now.

Protect it:
```bash
chmod 600 .env
```

### Start Services
```bash
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
| Pi-hole             | 10.2.0.3  | 53, 8082      | 53, 80        | http://pihole.home/admin |
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

### Pi-hole Setup

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

### Pi-hole Local DNS Records

Go to Pi-hole -> Local DNS -> DNS Records, add:
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

4get requires manual compilation for ARM64:
```bash
cd ~
git clone https://git.lolcat.ca/lolcat/4get.git
cd 4get

# Add CORS headers for Homepage integration (optional)
nvim api/v1/ac.php
```

Add at the top after `<?php`: (optional)
```php
<?php
header("Content-Type: application/json");
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, OPTIONS");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}
```

Build:
```bash
docker build --platform linux/arm64 -t 4get-arm:latest .
cd ~/pistack
docker compose up -d fourget
```

**Set up Git remotes: (optional)**
```bash
cd ~/4get
git remote add upstream https://git.lolcat.ca/lolcat/4get.git
git remote add origin git@gitea.home:jman/4get.git
git add api/v1/ac.php
git commit -m "Add CORS headers for autocomplete API"
git push -u origin main
```

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
- Backs up configs before updating
- Updates 4get from upstream
- Pulls latest Docker images
- Restarts containers
- Rolls back on failure
- Cleans up old backups
- Emails on errors

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

# Auto-update homelab every Sunday at 3 AM
0 3 * * 0 /home/jman/pistack/auto-update.sh >> /home/jman/pistack/cron.log 2>&1

# Email log if there were errors
5 3 * * 0 grep -iE "error|warning|critical" /home/jman/pistack/update.log | tail -50 | mail -s "⚠️ Homelab Update Issues" your-email@gmail.com || true
```

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
```bash
cd ~/pistack
docker compose pull
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
# Check Pi-hole
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
2. Rebuild: `docker build --platform linux/arm64 -t 4get-arm:latest .`
3. Check browser console for errors
4. Verify homepage/custom.js is loaded

## Support

For issues or questions:
- Check logs: `docker compose logs <service>`
- Check auto-update log: `tail ~/pistack/update.log`
- Restart service: `docker compose restart <service>`
- Full restart: `docker compose down && docker compose up -d`

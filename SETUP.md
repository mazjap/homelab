# Detailed Setup Guide

## Initial Setup

### 1. Install Docker
```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
```

### 2. Configure Secrets
```bash
cp .env.example .env
# Edit .env with your actual passwords
```

### 3. Create Service Directories
These will be auto-created by Docker, but you can pre-create:
```bash
mkdir -p pihole unbound wg-easy homepage gitea uptime-kuma portainer nginx-proxy-manager glances
```

### 4. Start Services
```bash
docker compose up -d
```

## Service Access

- Pi-hole: http://pihole.home/admin
- Homepage: http://homepage.home
- Gitea: http://gitea.home
- Portainer: http://192.168.0.40:9000
- Uptime Kuma: http://192.168.0.40:3001
- Nginx Manager: http://192.168.0.40:81

## Post-Setup

### Pi-hole
1. Set password: `docker exec pihole pihole setpassword`
2. Generate app password in Settings → API
3. Add to `.env` as `PIHOLE_API_KEY`

### Gitea
1. Complete web installer at http://gitea.home
2. Set SSH port to 2222
3. Create admin account

### Router Configuration
1. Set DNS to 192.168.0.40
2. Port forward 51820/udp to 192.168.0.40 (WireGuard)

## Backup & Restore

### Backup
```bash
tar -czf homelab-backup-$(date +%Y%m%d).tar.gz \
  --exclude='*/logs' \
  --exclude='*/*.log' \
  ~/pistack/
```

### Restore
```bash
tar -xzf homelab-backup.tar.gz
cd pistack
cp .env.example .env  # Fill in secrets
docker compose up -d
```

## Troubleshooting

### DNS not working
```bash
# Check Pi-hole
docker logs pihole
# Clear DNS cache on clients
sudo dscacheutil -flushcache  # macOS
```

### Service won't start
```bash
docker compose logs <service-name>
docker compose restart <service-name>
```

### Reset everything
```bash
docker compose down
docker system prune -a
docker compose up -d
```

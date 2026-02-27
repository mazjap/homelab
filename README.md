# My Homelab Infrastructure

Raspberry Pi 5 (8GB) running Docker-based homelab services.

## Services

- Pi-hole + Unbound (DNS + Ad Blocking)
- WireGuard VPN
- Gitea (Git Server)
- Homepage Dashboard
- 4get Search
- Uptime Kuma
- Portainer
- Nginx Proxy Manager

## Setup

1. Clone this repo
2. Copy `.env.example` to `.env` and fill in secrets
3. Run: `docker compose up -d`

## Network

- Pi IP: 192.168.0.40
- Docker Network: 10.2.0.0/24
- VPN Network: 10.8.0.0/24

See full documentation in [SETUP.md](SETUP.md)

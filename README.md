# My Homelab Infrastructure

Raspberry Pi 5 (8GB) running Docker-based homelab services.

## Services

- Pihole + Unbound (DNS + Ad Blocking)
- WireGuard VPN
- Gitea (Git Server)
- Homepage Dashboard
- 4get Search
- Uptime Kuma
- Portainer
- Nginx Proxy Manager
- Paperless
- Linkding

## Setup

See guide in [SETUP.md](SETUP.md)

## Network

- Pi IP: 192.168.0.40
- Docker Network: 10.2.0.0/24
- VPN Network: 10.8.0.0/24

## Evolution

This homelab project started as a simple Pihole DNS filter to block ads network wide. After discovering I could eliminate third party DNS resolvers like Google (8.8.8.8) and Cloudflare (1.1.1.1) by running my own recursive DNS server, I immediately added Unbound. Unlike forwarding DNS resolvers that send queries to centralized services, Unbound queries the DNS root servers directly and follows the chain to authoritative nameservers. This provides maximum privacy. No single third party sees all my DNS queries—at the cost of slightly higher latency (~50-100ms vs ~10-20ms for forwarded queries).

WireGuard VPN came next, giving me secure remote access to my home network and Pihole's ad blocking from anywhere. This meant maintaining privacy and blocking ads even when traveling or on public WiFi.

As services accumulated, I needed a unified dashboard. Homepage became my central hub, displaying all services with live status widgets and system monitoring via Glances. I integrated 4get, a privacy respecting search proxy, and built a custom search bar with live autocomplete—eliminating the need for Google's homepage while maintaining familiar search functionality.

Gitea transformed my homelab into a complete development environment. Self-hosting Git gave me unlimited private repositories for iOS projects, reverse engineering work, and school assignments, with full control over my code and no dependency on GitHub's availability. I configured it with SSH access on port 2222 and set up dual remotes—Gitea for private backup, GitHub for public sharing.

Since 4get requires manual compilation for ARM64, I forked the upstream repository, added CORS headers for Homepage integration, and currently host my modified version on Gitea.

Nginx Proxy Manager simplified access with clean domain names (gitea.home, pihole.home) instead of IP:port combinations. All services now route through reverse proxies with proper headers.

Uptime Kuma monitors all services, tracking availability and sending alerts when something goes down. Portainer provides a GUI for Docker management, making it easier to inspect containers and manage the stack visually.

Document management came with Paperless-ngx, which OCRs and organizes scanned documents, making everything searchable. Perfect for school transcripts, tax documents, and important papers. Linkding handles bookmark management with tagging and full text search, unifying my bookmarks across different devices and browsers.

The final piece was automation. I wrote an update script that runs every Sunday at 3 AM, backing up configs, pulling upstream changes for 4get, updating Docker images, restarting containers, and rolling back on failure. It emails me only when errors occur, keeping the homelab maintained with no manual intervention.

What started as ad blocking evolved into a complete self-hosted infrastructure: private DNS, VPN access, Git hosting, document management, search, monitoring, and automated maintenance, all running on a single Raspberry Pi 5.

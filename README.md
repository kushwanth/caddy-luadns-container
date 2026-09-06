# Caddy with LuaDNS & Layer 4 (L4)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Platforms](https://img.shields.io/badge/platforms-linux%2Famd64%20%7C%20linux%2Farm64-blue.svg)](#platform-support)

A production-ready, multi-architecture [Caddy](https://caddyserver.com/) container image featuring:
- **[LuaDNS ACME DNS-01 Provider](https://github.com/caddy-dns/luadns)**: Automated TLS certificate issuance and renewal via DNS-01 challenges, enabling wildcard certificates and secure HTTPS for private/internal servers behind NAT.
- **[Layer 4 (L4) Proxying & Streaming](https://github.com/mholt/caddy-l4)**: High-performance raw TCP/UDP stream routing, proxying, multiplexing, and protocol matching alongside HTTP/HTTPS.

---

## Table of Contents

- [Features](#features)
- [Container Details](#container-details)
- [Usage](#usage)
  - [Docker Run](#1-docker-run)
  - [Docker Compose](#2-docker-compose)
- [Sample Caddyfile Configurations](#sample-caddyfile-configurations)
  - [Global DNS-01 Configuration](#1-global-dns-01-challenge-all-sites)
  - [Per-Site DNS-01 Configuration](#2-per-site-configuration)
  - [Static Site with Compression](#3-static-site-with-gzip--zstd)
  - [Reverse Proxy](#4-reverse-proxy)
  - [Layer 4 (L4) TCP/UDP Proxying](#5-layer-4-l4-tcpudp-streaming)
- [Configuration & Credentials](#configuration--credentials)
  - [Obtaining LuaDNS Credentials](#obtaining-luadns-credentials)
  - [Setting Environment Variables](#setting-environment-variables)
- [Performance & Reliability](#performance--reliability)
  - [HTTP/3 (QUIC) & NET_ADMIN](#http3-quic--net_admin)
  - [Persistent Data & Rate Limits](#persistent-data--rate-limits)
  - [Troubleshooting DNS Propagation](#troubleshooting-dns-propagation)
- [Platform Support](#platform-support)
- [Published Tags](#published-tags)
- [Automated Maintenance (Renovate Dashboard)](#automated-maintenance)
- [License](#license)

---

## Features

- **Automated SSL/TLS**: Issues and renews Let's Encrypt / ZeroSSL certificates via LuaDNS DNS-01 challenge without exposing port 80.
- **Layer 4 Multiplexing**: Route raw TCP/UDP streams (SSH, databases, DNS, game servers) alongside HTTP traffic.
- **Multi-Platform Native Performance**: Built with Docker Buildx for `linux/amd64` and `linux/arm64` (Apple Silicon, AWS Graviton, Raspberry Pi 4/5).
- **Fast Cross-Compilation**: Utilizes Docker `--platform=$BUILDPLATFORM` for native Go compilation speed.
- **Lightweight & Secure**: Based on minimal Alpine Linux with built-in healthchecks and build-time module verification.
- **Automated Upstream Tracking**: Monitored by Renovate's Dependency Dashboard. Tracks upstream Caddy releases with release notes and changelogs without generating unrequested Pull Requests.

---

## Container Details

| Detail | Value |
| :--- | :--- |
| **Image Registry** | `ghcr.io/<owner>/caddy-luadns` |
| **Base Image** | `caddy:alpine` |
| **Supported Architectures** | `linux/amd64`, `linux/arm64` |
| **Published Tags** | `:latest` |

---

## Usage

### 1. Docker Run

```bash
docker run -d \
  --name caddy \
  --restart unless-stopped \
  --cap-add NET_ADMIN \
  -p 80:80 \
  -p 443:443 \
  -p 443:443/udp \
  -e LUADNS_EMAIL="user@example.com" \
  -e LUADNS_API_KEY="your-api-key" \
  -v ./Caddyfile:/etc/caddy/Caddyfile:ro \
  -v ./site:/srv:ro \
  -v caddy_data:/data \
  -v caddy_config:/config \
  ghcr.io/<owner>/caddy-luadns:latest
```

### 2. Docker Compose

```yaml
services:
  caddy:
    image: ghcr.io/<owner>/caddy-luadns:latest
    container_name: caddy
    restart: unless-stopped
    cap_add:
      - NET_ADMIN
    ports:
      - "80:80"
      - "443:443"
      - "443:443/udp"
    environment:
      - LUADNS_EMAIL=${LUADNS_EMAIL}
      - LUADNS_API_KEY=${LUADNS_API_KEY}
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - ./site:/srv:ro
      - caddy_data:/data
      - caddy_config:/config

volumes:
  caddy_data:
    # Defining caddy_data preserves certificates across 'docker compose down'
  caddy_config:
```

---

## Sample Caddyfile Configurations

### 1. Global DNS-01 Challenge (All Sites)

Set the ACME provider globally in the top-level block so every domain automatically uses LuaDNS:

```caddyfile
{
    acme_dns luadns {
        email   {env.LUADNS_EMAIL}
        api_key {env.LUADNS_API_KEY}
    }
}

*.example.com, example.com {
    respond "Secure wildcard domain via LuaDNS!" 200
}
```

### 2. Per-Site Configuration

Specify the DNS provider explicitly on an individual site:

```caddyfile
example.com {
    tls {
        dns luadns {
            email   {env.LUADNS_EMAIL}
            api_key {env.LUADNS_API_KEY}
        }
    }

    respond "Hello from Caddy with LuaDNS!" 200
}
```

### 3. Static Site with Gzip & Zstandard

```caddyfile
example.com {
    root * /srv
    encode zstd gzip
    file_server

    tls {
        dns luadns {
            email   {env.LUADNS_EMAIL}
            api_key {env.LUADNS_API_KEY}
        }
    }
}
```

### 4. Reverse Proxy

```caddyfile
api.example.com {
    reverse_proxy 127.0.0.1:8080 {
        header_up Host {upstream_hostport}
        header_up X-Real-IP {remote_host}
    }

    tls {
        dns luadns {
            email   {env.LUADNS_EMAIL}
            api_key {env.LUADNS_API_KEY}
        }
    }
}
```

### 5. Layer 4 (L4) TCP/UDP Streaming

Route raw TCP/UDP streams on custom ports alongside standard web traffic:

```caddyfile
{
    layer4 {
        # Raw TCP reverse proxy on port 5432 (e.g. Postgres)
        :5432 {
            route {
                proxy {
                    upstream 192.168.1.50:5432
                }
            }
        }
    }
}

# Web server continues running normally
example.com {
    respond "HTTP/HTTPS service active alongside L4 stream proxy!" 200
}
```

---

## Configuration & Credentials

### Obtaining LuaDNS Credentials

1. Log in to your account at [LuaDNS Dashboard](https://api.luadns.net/).
2. Navigate to **Account Settings** / **API Credentials**.
3. Locate your **Email Address** and generate an **API Key**.
4. Store these securely in your deployment environment (e.g., a `.env` file).

### Setting Environment Variables

Create a `.env` file alongside your `docker-compose.yml`:

```env
LUADNS_EMAIL=user@example.com
LUADNS_API_KEY=your_luadns_api_key_here
```

> [!CAUTION]
> Never hardcode API keys or credentials directly in your `Caddyfile` or commit them into git repositories.

---

## Performance & Reliability

### HTTP/3 (QUIC) & `NET_ADMIN`

Caddy supports HTTP/3 (QUIC) over UDP port `443/udp`. For optimal throughput and lower packet loss, Caddy automatically attempts to increase Linux kernel UDP receive and transmit buffer sizes (GSO).

Adding the `NET_ADMIN` capability (`--cap-add NET_ADMIN` in Docker or `cap_add: [NET_ADMIN]` in Compose) allows Caddy to tune these buffers without running as root, eliminating kernel buffer overrun warnings.

### Persistent Data & Rate Limits

Let's Encrypt enforces strict rate limits (e.g., 5 duplicate certificates per week). 

- **Always mount `/data`** to a persistent Docker named volume or host directory (`caddy_data:/data`).
- Certificates and ACME account keys are saved in `/data/caddy`.
- Mounting `/data` ensures certificates persist across container updates, restarts, and redeployments.

### Troubleshooting DNS Propagation

During initial certificate issuance, local recursive resolvers may cache NXDOMAIN responses before LuaDNS authoritative nameservers update the challenge TXT record. 

If challenge validation times out, specify public authoritative upstream resolvers in your `tls` block:

```caddyfile
tls {
    dns luadns {
        email   {env.LUADNS_EMAIL}
        api_key {env.LUADNS_API_KEY}
    }
    resolvers 1.1.1.1 8.8.8.8
}
```

---

## Platform Support

Multi-architecture images are built with native toolchains and QEMU emulation:

- **`linux/amd64`**: Standard 64-bit x86 servers, workstations, and cloud instances.
- **`linux/arm64`**: 64-bit ARM architectures (Apple Silicon Docker Desktop, AWS Graviton, Ampere Altra, Raspberry Pi 4 & 5 running 64-bit OS).

---

## Published Tags

Images published to GitHub Container Registry (`ghcr.io`) provide:

- **`:latest`**: Always tracks the latest stable build from the `main` branch, compiling the latest Caddy release with the latest LuaDNS and L4 plugins.

To pull the image:

```bash
docker pull ghcr.io/<owner>/caddy-luadns:latest
```

---

## Automated Maintenance

- Built from official upstream `caddy:builder-alpine` and `caddy:alpine` base images.
- Plugins (`github.com/caddy-dns/luadns` and `github.com/mholt/caddy-l4`) are compiled from their latest releases on build.
- Multi-platform images compile and publish to GHCR whenever a commit is pushed to `main`.
- **Renovate Dependency Dashboard**: Configured with `dependencyDashboardApproval: true` and `prCreation: "not-pending"`. Rather than creating automated PRs, Renovate maintains a dedicated **Dependency Dashboard** issue in the repository containing upstream release notes, SemVer diffs, and changelogs for human review.

---

## License

The packaging, Dockerfiles, and workflows in this repository are licensed under the [MIT License](LICENSE).

Upstream software packages compiled into the image are governed by their respective licenses:
- [Caddy](https://github.com/caddyserver/caddy): Apache-2.0
- [caddy-dns/luadns](https://github.com/caddy-dns/luadns): Apache-2.0
- [caddy-l4](https://github.com/mholt/caddy-l4): Apache-2.0

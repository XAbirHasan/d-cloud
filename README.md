# d-cloud

Turn any disk or folder into private cloud storage, accessible from all your devices.

Built on [Nextcloud](https://nextcloud.com) + Docker. Remote access via [Tailscale](https://tailscale.com) or [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/).

## Requirements

- [Docker](https://docs.docker.com/get-docker/) with Compose v2
- For remote access: [Tailscale](https://tailscale.com/download) or [cloudflared](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/installation/)

## Setup

```bash
git clone https://github.com/your-username/d-cloud.git
cd d-cloud
./setup.sh --disk /path/to/your/disk
```

Admin credentials and access URLs are printed when setup completes.

## Options

```
--disk <path>     Path to the disk or folder to share (required)
--tunnel <type>   tailscale (default) or cloudflare
--port <port>     Local port (default: 7070)
--admin <user>    Admin username (default: admin)
--interactive     Stream live logs during startup
```

## Remote access

**Tailscale** (default) — private, device-to-device. Only your devices can connect. → [Setup guide](docs/tailscale.md)

**Cloudflare Tunnel** — public HTTPS URL, no app needed. URL resets on every restart. → [Setup guide](docs/cloudflare.md)

## Accessing your files

| Client | How |
|---|---|
| **Browser** | Go to your local or remote URL and log in |
| **Desktop** | [Nextcloud Desktop app](https://nextcloud.com/install/#install-clients) → add server URL |
| **Mobile** | [Nextcloud iOS/Android](https://nextcloud.com/install/#install-clients) → add server URL |
| **WebDAV** | Mount `http://localhost:7070/remote.php/dav/files/<username>/` |

## Management

```bash
./restart.sh          # restart containers + tunnel
./teardown.sh         # stop everything (prompts before deleting data)

docker compose logs -f nextcloud   # live logs
docker compose ps                  # container status
```

## Troubleshooting

**"Untrusted domain" error** — add your IP/domain in Nextcloud under `Settings → Administration → Basic settings → Trusted domains`.

**Port already in use** — use `--port 7171` (or any free port).

**Permission denied on disk** — run `sudo chmod 777 /path/to/your/disk` then retry setup.

**Nextcloud stuck / not starting**
```bash
docker compose logs -f nextcloud   # check for errors
docker compose logs -f db          # check database
docker compose ps                  # check container states
```

**Cloudflare tunnel URL not appearing**
```bash
cat .cloudflared.log   # check tunnel output
```

**Start fresh after a failed setup**
```bash
./teardown.sh   # choose to remove data when prompted
./setup.sh --disk /path/to/your/disk
```

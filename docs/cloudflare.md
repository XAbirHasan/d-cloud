# Remote access with Cloudflare Tunnel

Cloudflare Tunnel gives you a public HTTPS URL without opening any ports or configuring DNS. Anyone with the URL and your login credentials can access your Nextcloud.

## 1. Install cloudflared on the host machine

**macOS**
```bash
brew install cloudflared
```

**Linux**
```bash
curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 \
  -o /usr/local/bin/cloudflared
chmod +x /usr/local/bin/cloudflared
```

**Other platforms:** https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/installation/

## 2. Run d-cloud with Cloudflare Tunnel

```bash
./d-cloud.sh setup --disk /path/to/your/disk --tunnel cloudflare
```

A temporary public URL like `https://something-random.trycloudflare.com` is printed at the end of setup. Open it in any browser — no app or VPN needed.

## Using the Nextcloud app

**Desktop (Mac/Windows/Linux):** [Download](https://nextcloud.com/install/#install-clients) → open → click *Log in* → enter your Cloudflare tunnel URL as the server → log in with your admin credentials. Files sync automatically to a local folder.

**Mobile (iOS/Android):** [Download](https://nextcloud.com/install/#install-clients) → tap *Log in* → enter your Cloudflare tunnel URL → log in.

> Note: since the tunnel URL changes on every restart, you'll need to update the server URL in the app after each restart. For a permanent URL, set up a [named tunnel](#permanent-url-named-tunnel).

## Restarting

Run `./d-cloud.sh start` — a new tunnel URL is generated and printed automatically.

## Permanent URL (named tunnel)

The quick tunnel URL changes on every restart. For a stable URL tied to your own domain:

1. Create a [Cloudflare account](https://dash.cloudflare.com) and add your domain
2. Follow the [Named Tunnel guide](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/tunnel-guide/)
3. Replace the `cloudflared tunnel --url ...` command in `setup.sh` and `restart.sh` with your named tunnel command

## Notes

- The host machine must be running for the tunnel to be active.
- The quick tunnel is unauthenticated at the network level — Nextcloud's login page is your only protection. Use a strong password.
- HTTPS is enforced by Cloudflare automatically.

# Remote access with Tailscale

Tailscale creates a private encrypted network between your devices. Only devices on your Tailscale account can reach your d-cloud instance — nothing is exposed to the public internet.

## 1. Install Tailscale on the host machine

Follow the guide for your OS: https://tailscale.com/download

Start and log in:

```bash
sudo tailscale up
```

## 2. Run d-cloud with Tailscale

```bash
./setup.sh --disk /path/to/your/disk --tunnel tailscale
```

Your Tailscale IP is detected automatically and added to Nextcloud's trusted domains. The access URL is printed at the end of setup, e.g. `http://100.x.x.x:7070`.

## 3. Connect from another device

Install Tailscale on the other device (phone, laptop, etc.) and log in with the **same Tailscale account**.

Once connected, open `http://<tailscale-ip>:7070` in a browser, or add that URL as the server in the Nextcloud mobile/desktop app.

## Using the Nextcloud app

**Desktop (Mac/Windows/Linux):** [Download](https://nextcloud.com/install/#install-clients) → open → click *Log in* → enter `http://<tailscale-ip>:7070` as the server URL → log in with your admin credentials. Your files will sync automatically to a local folder.

**Mobile (iOS/Android):** [Download](https://nextcloud.com/install/#install-clients) → tap *Log in* → enter `http://<tailscale-ip>:7070` → log in. Make sure Tailscale is also running on your phone.

> You can find your Tailscale IP anytime by running `tailscale ip -4` on the host.

## Notes

- The host machine must be running and Tailscale must be connected for remote access to work.
- No port forwarding or firewall rules needed.
- Traffic never leaves your private Tailscale network.

# Enabling HTTPS for the SLV API (Let's Encrypt + nginx)

The API currently serves plain HTTP, so logins and tokens cross the wire in
cleartext. This sets up a free, auto-renewing TLS certificate on the VPS.

**Prerequisites**
- SSH access to the VPS as root (or a sudo user).
- The domain must resolve to the server. The Hostinger hostname
  `srv1782538.hstgr.cloud` already does. If you use a custom domain, point its
  `A` record at `187.127.186.206` first and wait for DNS to propagate.
- Port 80 and 443 open in the firewall.

All commands run **on the server**.

---

## Option A — let certbot configure nginx for you (easiest)

```bash
# 1. Install certbot + the nginx plugin
sudo apt update
sudo apt install -y certbot python3-certbot-nginx

# 2. Obtain a cert AND auto-edit the running nginx config to use it.
#    Choose "redirect" when asked, so HTTP is forced to HTTPS.
sudo certbot --nginx -d srv1782538.hstgr.cloud

# 3. Confirm auto-renewal is armed (certbot installs a systemd timer)
sudo systemctl list-timers | grep certbot
sudo certbot renew --dry-run
```

That's it — certbot rewrites the existing `nginx.conf` server block in place and
reloads nginx. Skip Option B.

---

## Option B — use the provided `nginx-tls.conf` (explicit config)

Use this if you'd rather manage the config from this repo.

```bash
# 1. Install certbot (no nginx plugin needed for webroot mode)
sudo apt update
sudo apt install -y certbot

# 2. Create the ACME webroot referenced by nginx-tls.conf
sudo mkdir -p /var/www/certbot

# 3. Obtain the certificate via the webroot challenge.
#    (Your current HTTP nginx must be serving /.well-known/acme-challenge/ —
#     the redirect block in nginx-tls.conf already does once installed; for the
#     very first issue you can instead use:  sudo certbot certonly --standalone
#     after briefly stopping nginx.)
sudo certbot certonly --webroot -w /var/www/certbot -d srv1782538.hstgr.cloud

# 4. Install the repo's TLS config and reload
sudo cp /opt/slv/nginx-tls.conf /etc/nginx/sites-available/slv.conf
sudo ln -sf /etc/nginx/sites-available/slv.conf /etc/nginx/sites-enabled/slv.conf
sudo nginx -t            # validate syntax
sudo systemctl reload nginx

# 5. Verify renewal works
sudo certbot renew --dry-run
```

> Adjust paths (`/opt/slv/...`, `sites-available`) to match how nginx is laid
> out on the box. If nginx uses a single `/etc/nginx/nginx.conf` with an
> `http {}` block instead of `sites-enabled`, paste the `server { }` blocks from
> `nginx-tls.conf` into that file instead.

---

## After HTTPS is live — point the apps at it

The backend itself needs no change (nginx terminates TLS and proxies to
gunicorn on `127.0.0.1:8000` as before). Update the clients:

- **Production APK** — build against the HTTPS URL:
  ```bash
  flutter build apk --dart-define=API_BASE_URL=https://srv1782538.hstgr.cloud
  ```
- **Dev APK** — `https://srv1782538.hstgr.cloud:8443` (per `nginx-tls.conf`).
- Once every client is on HTTPS you can drop `usesCleartextTraffic` from the
  Android manifest and tighten `CORS_ORIGINS` in `backend/.env`.

## Sanity checks

```bash
curl -I https://srv1782538.hstgr.cloud/health     # 200, valid cert
curl -I http://srv1782538.hstgr.cloud/health      # 301 → https
```

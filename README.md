[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template/easyappointments-1?utm_medium=integration&utm_source=button&utm_campaign=easyappointments)

# Easy!Appointments on Railway

One-click [Easy!Appointments](https://easyappointments.org) (open-source appointment scheduler, GPL-3.0) for Railway.

**Version:** Easy!Appointments `1.6.1`, from the official image
`alextselegidis/easyappointments:1.6.1@sha256:6d3a927dc16db11827018bcbc708e6ee7d4be7f577e5d0967e90a1b08b71e2e0`
(pinned by version and digest in the [`Dockerfile`](Dockerfile)).

## What the template deploys

| Service | Source | Volume | Notes |
|---|---|---|---|
| **Easy!Appointments** | this repo (`Dockerfile`) | `/var/www/html/storage` | PHP + Apache on port 8080, public Railway domain, health check `/healthz/` |
| **MySQL** | Railway's MySQL | `/var/lib/mysql` | private network only, no public TCP proxy |

On the first visit the app opens its installation page, where you create the administrator account and enter your company details. There is no default login.

The wrapper is small:

- [`railway-start.sh`](railway-start.sh) writes `config.php` and the email config from the service variables at every start (values are escaped by PHP), seeds the storage volume on first boot, applies pending database migrations after an update, makes Apache listen on `PORT` and starts Apache.
- [`remoteip.conf`](remoteip.conf) makes Apache take the visitor's IP from Railway's `X-Real-IP` header. Easy!Appointments ties each login session to the client IP, and behind Railway's proxy every request would otherwise come from a different internal address and log you out.
- [`healthz.php`](healthz.php) answers `200` on `/healthz/` when the database is reachable, `503` otherwise.
- [`zz-railway.ini`](zz-railway.ini) turns off the upstream image's xdebug and PHP error display.

## Variables

| Variable | Default | Purpose |
|---|---|---|
| `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USERNAME`, `DB_PASSWORD` | references to the MySQL service | database connection |
| `BASE_URL` | `https://${{RAILWAY_PUBLIC_DOMAIN}}` | public URL used in emails and links; change it if you add a custom domain |
| `ENCRYPTION_KEY` | `${{secret(48)}}` | session encryption key, generated per deploy |
| `PORT` | `8080` | port Apache listens on |

Optional, add them to the Easy!Appointments service when you need them:

- **Email (SMTP):** `MAIL_SMTP_HOST`, `MAIL_SMTP_PORT` (default `587`), `MAIL_SMTP_USER`, `MAIL_SMTP_PASS`, `MAIL_SMTP_CRYPTO` (`tls` or `ssl`), `MAIL_FROM_ADDRESS`, `MAIL_FROM_NAME`, `MAIL_REPLY_TO_ADDRESS`. Setting `MAIL_SMTP_HOST` switches the mailer to SMTP. Railway blocks outbound SMTP on the Free and Trial plans, so use a paid plan or an HTTP-relay provider's SMTP port that Railway allows.
- **Google Calendar sync:** `GOOGLE_SYNC_FEATURE=true`, `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET` (can also be set in the admin UI under Integrations).
- `LANGUAGE` (default `english`), `DEBUG_MODE` (default `false`).

## Updates

Deployers get Railway's "update available" notice when this repo's `main` branch changes. Each version bump is listed in [`CHANGELOG.md`](CHANGELOG.md), breaking changes first. When you apply an update, the start script runs `php index.php console migrate` on an installed instance, so database migrations are applied automatically (see the [upstream update guide](https://github.com/alextselegidis/easyappointments/blob/1.6.1/docs/update-guide.md)). Back up first: `php index.php console backup` in the service shell writes a dump to `storage/backups` on the volume.

## Local run

```sh
docker build -t easyappointments-railway .
docker run -p 8080:8080 -e DB_HOST=... -e DB_NAME=... -e DB_USERNAME=... -e DB_PASSWORD=... \
  -e ENCRYPTION_KEY=$(openssl rand -hex 24) -e PORT=8080 -v ea-storage:/var/www/html/storage easyappointments-railway
```

Easy!Appointments is © Alex Tselegidis, GPL-3.0. This wrapper is GPL-3.0 too.

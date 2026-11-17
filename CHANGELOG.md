# Changelog

Breaking changes are listed first in each entry.

## 1.6.1 (2026-11-17)

- First release of this Railway template: Easy!Appointments 1.6.1, official image pinned by digest
  `sha256:6d3a927dc16db11827018bcbc708e6ee7d4be7f577e5d0967e90a1b08b71e2e0`.
- Railway MySQL on the private network, storage (sessions, uploads, backups) on a volume,
  generated `ENCRYPTION_KEY`, health check on `/healthz/`.
- Client IP from Railway's `X-Real-IP` (Apache `mod_remoteip`), so login sessions survive Railway's
  load-balanced proxy (Easy!Appointments matches sessions to the client IP).

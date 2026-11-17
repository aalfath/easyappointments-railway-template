#!/bin/bash
# Start script for Easy!Appointments on Railway.
# Writes config.php and email.php from the environment, seeds the storage volume,
# makes Apache listen on $PORT and starts it in the foreground.
set -euo pipefail

APP=/var/www/html

# Defaults for settings the template doesn't ask for.
export PORT="${PORT:-8080}"
export LANGUAGE="${LANGUAGE:-english}"
export DEBUG_MODE="${DEBUG_MODE:-false}"
export DB_PORT="${DB_PORT:-3306}"
if [ -z "${BASE_URL:-}" ] && [ -n "${RAILWAY_PUBLIC_DOMAIN:-}" ]; then
    export BASE_URL="https://${RAILWAY_PUBLIC_DOMAIN}"
fi
export BASE_URL="${BASE_URL:-http://localhost}"
if [ -z "${MAIL_PROTOCOL:-}" ]; then
    if [ -n "${MAIL_SMTP_HOST:-}" ]; then export MAIL_PROTOCOL=smtp; else export MAIL_PROTOCOL=mail; fi
fi

for v in DB_HOST DB_NAME DB_USERNAME DB_PASSWORD; do
    if [ -z "${!v:-}" ]; then echo "railway-start: $v is not set" >&2; exit 1; fi
done
if [ -z "${ENCRYPTION_KEY:-}" ]; then
    echo "railway-start: ENCRYPTION_KEY is not set; sessions fall back to a key derived from the host name" >&2
fi

# config.php and email.php, written by PHP so that any character in a value is escaped safely.
php <<'PHP'
<?php
$e = fn($k, $d = '') => (getenv($k) === false || getenv($k) === '') ? $d : getenv($k);
$b = fn($k, $d) => filter_var($e($k, $d), FILTER_VALIDATE_BOOLEAN);
$hostPort = $e('DB_PORT', '3306') === '3306' ? $e('DB_HOST') : $e('DB_HOST') . ':' . $e('DB_PORT');
$cfg = "<?php\n// Written by railway-start.sh at every start. Change the service variables, not this file.\n";
if ($e('ENCRYPTION_KEY') !== '') {
    $cfg .= "define('ENCRYPTION_KEY', " . var_export($e('ENCRYPTION_KEY'), true) . ");\n";
}
$cfg .= "class Config\n{\n";
foreach ([
    'BASE_URL' => rtrim($e('BASE_URL'), '/'),
    'LANGUAGE' => $e('LANGUAGE', 'english'),
    'DEBUG_MODE' => $b('DEBUG_MODE', 'false'),
    'DB_HOST' => $hostPort,
    'DB_NAME' => $e('DB_NAME'),
    'DB_USERNAME' => $e('DB_USERNAME'),
    'DB_PASSWORD' => $e('DB_PASSWORD'),
    'GOOGLE_SYNC_FEATURE' => $b('GOOGLE_SYNC_FEATURE', 'false'),
    'GOOGLE_CLIENT_ID' => $e('GOOGLE_CLIENT_ID'),
    'GOOGLE_CLIENT_SECRET' => $e('GOOGLE_CLIENT_SECRET'),
] as $k => $v) {
    $cfg .= "    const $k = " . var_export($v, true) . ";\n";
}
$cfg .= "}\n";
file_put_contents('/var/www/html/config.php', $cfg);

$mail = [
    'useragent' => 'Easy!Appointments',
    'protocol' => $e('MAIL_PROTOCOL', 'mail'),
    'mailtype' => 'html',
    'smtp_debug' => $e('MAIL_SMTP_DEBUG', '0'),
    'smtp_auth' => $b('MAIL_SMTP_AUTH', $e('MAIL_SMTP_USER') !== '' ? 'true' : 'false'),
    'smtp_host' => $e('MAIL_SMTP_HOST'),
    'smtp_user' => $e('MAIL_SMTP_USER'),
    'smtp_pass' => $e('MAIL_SMTP_PASS'),
    'smtp_crypto' => $e('MAIL_SMTP_CRYPTO', 'tls'),
    'smtp_port' => (int) $e('MAIL_SMTP_PORT', '587'),
    'from_name' => $e('MAIL_FROM_NAME'),
    'from_address' => $e('MAIL_FROM_ADDRESS'),
    'reply_to' => $e('MAIL_REPLY_TO_ADDRESS'),
    'crlf' => "\r\n",
    'newline' => "\r\n",
];
$out = "<?php defined('BASEPATH') or exit('No direct script access allowed');\n// Written by railway-start.sh at every start.\n";
foreach ($mail as $k => $v) {
    $out .= '$config[' . var_export($k, true) . '] = ' . var_export($v, true) . ";\n";
}
file_put_contents('/var/www/html/application/config/email.php', $out);
PHP
chown root:www-data "$APP/config.php" "$APP/application/config/email.php"
chmod 640 "$APP/config.php" "$APP/application/config/email.php"

# Storage (sessions, uploads, cache, logs, backups) lives on the Railway volume.
# A new volume is empty, so copy the image's tree in without overwriting anything.
mkdir -p "$APP/storage"
cp -an /opt/easyappointments-storage/. "$APP/storage/"
rm -rf "$APP/storage/lost+found"
chown -R www-data:www-data "$APP/storage"

# Railway's image unpacking can bring back mpm_event next to mpm_prefork
# ("AH00534: More than one MPM loaded"). mod_php needs prefork only.
rm -f /etc/apache2/mods-enabled/mpm_event.* /etc/apache2/mods-enabled/mpm_worker.*
[ -e /etc/apache2/mods-enabled/mpm_prefork.load ] || a2enmod -q mpm_prefork
# mod_remoteip takes the visitor's IP from Railway's X-Real-IP (see railway-remoteip.conf).
[ -e /etc/apache2/mods-enabled/remoteip.load ] || a2enmod -q remoteip

# After an image update, apply pending database migrations, but only on an
# installed instance (on an empty database the installation page does this).
cd "$APP"
if php /usr/local/bin/railway-installed.php; then
    echo "railway-start: installed instance found, applying pending migrations"
    su -s /bin/sh www-data -c 'php index.php console migrate' \
        || echo "railway-start: migration failed, see storage/logs; the app starts anyway" >&2
else
    echo "railway-start: no installation yet (or database not reachable); open the site to run the installer"
fi

# Listen on $PORT.
sed -ri "s/^Listen [0-9]+$/Listen ${PORT}/" /etc/apache2/ports.conf
sed -ri "s/<VirtualHost \*:[0-9]+>/<VirtualHost *:${PORT}>/" /etc/apache2/sites-enabled/000-default.conf

echo "railway-start: Easy!Appointments ready on port ${PORT} (${BASE_URL})"
exec apache2-foreground

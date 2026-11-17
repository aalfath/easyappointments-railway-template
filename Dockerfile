# Easy!Appointments for Railway: the official image, pinned by version and digest.
# Upstream: https://github.com/alextselegidis/easyappointments-docker
FROM alextselegidis/easyappointments:1.6.1@sha256:6d3a927dc16db11827018bcbc708e6ee7d4be7f577e5d0967e90a1b08b71e2e0

# Production PHP settings (the upstream image ships with xdebug in debug mode).
COPY zz-railway.ini /usr/local/etc/php/conf.d/zz-railway.ini

# Real client IP from Railway's proxy (see remoteip.conf).
COPY remoteip.conf /etc/apache2/conf-available/railway-remoteip.conf
RUN a2enmod remoteip && a2enconf railway-remoteip

# Health check for Railway: answers 200 only when PHP and MySQL are reachable.
COPY healthz.php /var/www/html/healthz/index.php

# Keep a pristine copy of the storage tree, to seed an empty Railway volume.
RUN cp -a /var/www/html/storage /opt/easyappointments-storage \
    && chown -R www-data:www-data /var/www/html/healthz

COPY railway-start.sh railway-installed.php /usr/local/bin/
RUN chmod 755 /usr/local/bin/railway-start.sh

EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/railway-start.sh"]

#!/bin/bash
#
# Добавление bookworm.breget.tech в nginx + Let's Encrypt SSL.
# Только новый vhost — существующие сайты не трогает.
#
# На сервере:
#   cd ~/bookworm && sudo ./script/setup-nginx.sh
#
# С локальной машины:
#   ./script/setup-nginx-remote.sh
#
# Переменные из .env:
#   BOOKWORM_DOMAIN          — bookworm.breget.tech
#   WEB_PORT                 — 3020
#   BOOKWORM_LETSENCRYPT_EMAIL — email для Let's Encrypt
#
# Нужны: nginx, certbot (или Docker certbot/certbot), DNS A → сервер.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ -f "$PROJECT_ROOT/.env" ]; then
  set -a
  # shellcheck source=/dev/null
  source "$PROJECT_ROOT/.env"
  set +a
fi

BOOKWORM_DOMAIN="${BOOKWORM_DOMAIN:-bookworm.breget.tech}"
WEB_PORT="${WEB_PORT:-3020}"
BOOKWORM_LETSENCRYPT_EMAIL="${BOOKWORM_LETSENCRYPT_EMAIL:-${LETSENCRYPT_EMAIL:-}}"

CERTBOT_WWW_DEST="/var/www/certbot"
NGINX_SA="/etc/nginx/sites-available"
NGINX_SE="/etc/nginx/sites-enabled"
SITE_CONF_NAME="${BOOKWORM_DOMAIN}.conf"
SITE_CONF_PATH="${NGINX_SA}/${SITE_CONF_NAME}"
SSL_FULLCHAIN="/etc/letsencrypt/live/${BOOKWORM_DOMAIN}/fullchain.pem"
SSL_PRIVKEY="/etc/letsencrypt/live/${BOOKWORM_DOMAIN}/privkey.pem"
UPSTREAM_NAME="bookworm_app"

log() { echo "==> $*"; }

if [ "$(id -u)" -ne 0 ]; then
  echo "Запустите с sudo: sudo $0"
  exit 1
fi

if ! command -v nginx >/dev/null 2>&1; then
  echo "nginx не найден: sudo apt install nginx"
  exit 1
fi

if [ -z "$BOOKWORM_LETSENCRYPT_EMAIL" ]; then
  echo "Укажите BOOKWORM_LETSENCRYPT_EMAIL в .env (email для Let's Encrypt)"
  exit 1
fi

if [ -f "$SSL_FULLCHAIN" ] && [ -f "$SSL_PRIVKEY" ]; then
  log "Сертификат уже есть — обновляю только nginx-конфиг для ${BOOKWORM_DOMAIN}"
  SKIP_CERTBOT=1
else
  SKIP_CERTBOT=0
fi

mkdir -p "$CERTBOT_WWW_DEST"

if [ "$SKIP_CERTBOT" = "0" ]; then
  log "Фаза 1: временный HTTP для ACME challenge (${BOOKWORM_DOMAIN})"

  cat > "$SITE_CONF_PATH" << EOF
# ${BOOKWORM_DOMAIN} — фаза 1 (bookworm setup-nginx.sh)
server {
    listen 80;
    listen [::]:80;
    server_name ${BOOKWORM_DOMAIN};

    location /.well-known/acme-challenge/ {
        root ${CERTBOT_WWW_DEST};
        try_files \$uri =404;
    }

    location / {
        return 200 "OK\n";
        add_header Content-Type text/plain;
    }
}
EOF

  ln -sf "$SITE_CONF_PATH" "${NGINX_SE}/${SITE_CONF_NAME}"
  nginx -t
  systemctl reload nginx 2>/dev/null || service nginx reload 2>/dev/null || nginx -s reload

  log "Фаза 2: выпуск сертификата Let's Encrypt"
  if command -v certbot >/dev/null 2>&1; then
    certbot certonly --webroot -w "$CERTBOT_WWW_DEST" -d "$BOOKWORM_DOMAIN" \
      --email "$BOOKWORM_LETSENCRYPT_EMAIL" --agree-tos --non-interactive --expand
  else
    log "certbot не в PATH — Docker certbot/certbot"
    docker run --rm \
      -v /etc/letsencrypt:/etc/letsencrypt \
      -v "${CERTBOT_WWW_DEST}:${CERTBOT_WWW_DEST}" \
      certbot/certbot certonly --webroot -w "$CERTBOT_WWW_DEST" \
      -d "$BOOKWORM_DOMAIN" --email "$BOOKWORM_LETSENCRYPT_EMAIL" --agree-tos --non-interactive --expand
  fi
fi

log "Фаза 3: HTTPS + proxy → 127.0.0.1:${WEB_PORT}"

cat > "$SITE_CONF_PATH" << EOF
# ${BOOKWORM_DOMAIN} — dynamic-mcp (script/setup-nginx.sh)
upstream ${UPSTREAM_NAME} {
    server 127.0.0.1:${WEB_PORT};
    keepalive 32;
}

server {
    listen 80;
    listen [::]:80;
    server_name ${BOOKWORM_DOMAIN};

    location /.well-known/acme-challenge/ {
        root ${CERTBOT_WWW_DEST};
        try_files \$uri =404;
    }

    location / {
        return 301 https://\$host\$request_uri;
    }
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name ${BOOKWORM_DOMAIN};

    ssl_certificate ${SSL_FULLCHAIN};
    ssl_certificate_key ${SSL_PRIVKEY};
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;

    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    client_max_body_size 200M;

    location / {
        proxy_pass http://${UPSTREAM_NAME};
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header Connection "";

        # MCP SSE и долгие импорты
        proxy_buffering off;
        proxy_read_timeout 600s;
        proxy_send_timeout 600s;
    }
}
EOF

ln -sf "$SITE_CONF_PATH" "${NGINX_SE}/${SITE_CONF_NAME}"
nginx -t
systemctl reload nginx 2>/dev/null || service nginx reload 2>/dev/null || nginx -s reload

echo ""
echo "Готово: https://${BOOKWORM_DOMAIN}"
echo "Прокси: 127.0.0.1:${WEB_PORT}"
echo ""
echo "Обновите .env на сервере (~/bookworm/.env):"
echo "  PUBLIC_HOST=${BOOKWORM_DOMAIN}"
echo "  PUBLIC_SCHEME=https"
echo "  MCP_ALLOWED_ORIGINS=${BOOKWORM_DOMAIN},localhost,127.0.0.1"
echo ""
echo "Затем: cd ~/bookworm && docker-compose up -d web"
echo "Продление: certbot renew --webroot -w ${CERTBOT_WWW_DEST}"

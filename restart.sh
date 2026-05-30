#!/bin/bash
# Рестарт контейнеров на демо-стенде.
#   ./restart.sh

cd "$(dirname "$0")"

if [ -f .env ]; then
  set -a
  # shellcheck source=/dev/null
  source .env
  set +a
fi

if [ -z "${DEPLOY_SERVER:-}" ] || [ -z "${DEPLOY_PATH:-}" ]; then
  echo "❌ Укажите DEPLOY_SERVER и DEPLOY_PATH в .env"
  exit 1
fi

set -e

SSH_OPTS="-o ServerAliveInterval=30 -o ServerAliveCountMax=20"
COMPOSE_CMD=$(ssh $SSH_OPTS "$DEPLOY_SERVER" "if command -v docker-compose >/dev/null 2>&1; then echo docker-compose; else echo 'docker compose'; fi")

echo "🔄 Рестарт на $DEPLOY_SERVER ($DEPLOY_PATH)"
echo ""

ssh $SSH_OPTS "$DEPLOY_SERVER" "cd $DEPLOY_PATH && $COMPOSE_CMD down --remove-orphans"
ssh $SSH_OPTS "$DEPLOY_SERVER" "cd $DEPLOY_PATH && $COMPOSE_CMD up -d --remove-orphans"

echo ""
echo "✅ Рестарт завершён"
ssh $SSH_OPTS "$DEPLOY_SERVER" "cd $DEPLOY_PATH && $COMPOSE_CMD ps"

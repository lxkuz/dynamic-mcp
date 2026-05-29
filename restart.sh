#!/bin/bash
# Рестарт контейнеров на удалённом сервере.
#   ./restart.sh production|staging|prod|stage
#   ./restart.sh [--target production|staging]

cd "$(dirname "$0")"

if [ -f .env ]; then
  set -a
  source .env
  set +a
fi

# shellcheck source=scripts/deploy_resolve.sh
source "$(dirname "$0")/scripts/deploy_resolve.sh"

TARGET="${DEPLOY_TARGET:-}"
while [ $# -gt 0 ]; do
  case "$1" in
    --target|-e)
      TARGET="$2"
      shift 2
      ;;
    production|prod|staging|stage)
      TARGET="$1"
      shift
      ;;
    -h|--help)
      echo "Использование: $0 [production|staging|prod|stage] [--target …]"
      exit 0
      ;;
    *)
      echo "❌ Неизвестный аргумент: $1"
      exit 1
      ;;
  esac
done

if [ -z "$TARGET" ]; then
  echo "❌ Укажите окружение: ./restart.sh prod | staging"
  exit 1
fi

if ! resolve_deploy_target "$TARGET"; then
  exit 1
fi

set -e

SSH_OPTS="-o ServerAliveInterval=30 -o ServerAliveCountMax=20"
COMPOSE_CMD=$(ssh $SSH_OPTS "$DEPLOY_SERVER" "if command -v docker-compose >/dev/null 2>&1; then echo docker-compose; else echo 'docker compose'; fi")

echo "🌍 Окружение: $TARGET"
echo "🔄 Рестарт на $DEPLOY_SERVER ($DEPLOY_PATH)"
echo ""

ssh $SSH_OPTS "$DEPLOY_SERVER" "cd $DEPLOY_PATH && $COMPOSE_CMD down --remove-orphans"
ssh $SSH_OPTS "$DEPLOY_SERVER" "cd $DEPLOY_PATH && $COMPOSE_CMD up -d --remove-orphans"

echo ""
echo "✅ Рестарт завершён"
ssh $SSH_OPTS "$DEPLOY_SERVER" "cd $DEPLOY_PATH && $COMPOSE_CMD ps"

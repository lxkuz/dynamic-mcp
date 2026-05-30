#!/bin/bash
# Логи docker-compose на демо-стенде.
#   ./logs.sh [-f] [web|sidekiq|elasticsearch]

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

FOLLOW=""
SERVICE=""
while [ $# -gt 0 ]; do
  case "$1" in
    -f|--follow)
      FOLLOW="-f"
      shift
      ;;
    -h|--help)
      echo "Использование: $0 [-f] [web|sidekiq|elasticsearch]"
      exit 0
      ;;
    *)
      SERVICE="$1"
      shift
      ;;
  esac
done

SSH_OPTS="-o ServerAliveInterval=30 -o ServerAliveCountMax=20"
COMPOSE_CMD=$(ssh $SSH_OPTS "$DEPLOY_SERVER" "command -v docker-compose >/dev/null 2>&1 && echo docker-compose || echo 'docker compose'")

ssh $SSH_OPTS "$DEPLOY_SERVER" "cd $DEPLOY_PATH && $COMPOSE_CMD logs $FOLLOW --tail=200 $SERVICE"

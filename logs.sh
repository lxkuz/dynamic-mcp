#!/bin/bash
# Логи docker-compose на удалённом сервере.
#   ./logs.sh production [-f] [web|elasticsearch|web_migrate]

cd "$(dirname "$0")"

if [ -f .env ]; then
  set -a
  source .env
  set +a
fi

# shellcheck source=scripts/deploy_resolve.sh
source "$(dirname "$0")/scripts/deploy_resolve.sh"

TARGET="${DEPLOY_TARGET:-}"
FOLLOW=""
SERVICE=""
args=()
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
    -f|--follow)
      FOLLOW="-f"
      shift
      ;;
    -h|--help)
      echo "Использование: $0 [prod|staging] [-f] [web|elasticsearch]"
      exit 0
      ;;
    *)
      args+=("$1")
      shift
      ;;
  esac
done
set -- "${args[@]}"
while [ $# -gt 0 ]; do
  case "$1" in
    -f|--follow) FOLLOW="-f"; shift ;;
    *) SERVICE="$1"; shift ;;
  esac
done

if [ -z "$TARGET" ]; then
  echo "❌ Укажите окружение: ./logs.sh production"
  exit 1
fi

if ! resolve_deploy_target "$TARGET"; then
  exit 1
fi

SSH_OPTS="-o ServerAliveInterval=30 -o ServerAliveCountMax=20"
COMPOSE_CMD=$(ssh $SSH_OPTS "$DEPLOY_SERVER" "if command -v docker-compose >/dev/null 2>&1; then echo docker-compose; else echo 'docker compose'; fi")

ssh $SSH_OPTS "$DEPLOY_SERVER" "cd $DEPLOY_PATH && $COMPOSE_CMD logs $FOLLOW --tail=200 $SERVICE"

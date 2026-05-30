#!/bin/bash
#
# Запуск setup-nginx.sh на демо-стенде по SSH (с локальной машины).
#   ./script/setup-nginx-remote.sh
#
# Читает DEPLOY_SERVER, DEPLOY_PATH, DEPLOY_GIT_SSH_KEY из .env.
# На сервере потребуется sudo-пароль.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ -f "$PROJECT_ROOT/.env" ]; then
  set -a
  # shellcheck source=/dev/null
  source "$PROJECT_ROOT/.env"
  set +a
fi

if [ -z "${DEPLOY_SERVER:-}" ] || [ -z "${DEPLOY_PATH:-}" ]; then
  echo "Укажите DEPLOY_SERVER и DEPLOY_PATH в .env"
  exit 1
fi

SSH_OPTS="-o ServerAliveInterval=30 -o ServerAliveCountMax=20"
BRANCH="${DEPLOY_BRANCH:-main}"

GIT_CMD="git fetch origin && git checkout \"${BRANCH}\" && git pull origin \"${BRANCH}\""
if [ -n "${DEPLOY_GIT_SSH_KEY:-}" ]; then
  GIT_CMD="export GIT_SSH_COMMAND=\"ssh -i ${DEPLOY_GIT_SSH_KEY} -o IdentitiesOnly=yes -o StrictHostKeyChecking=no\" && ${GIT_CMD}"
fi

echo "Nginx + SSL для ${BOOKWORM_DOMAIN:-bookworm.breget.tech}"
echo "Сервер: $DEPLOY_SERVER:$DEPLOY_PATH"
echo "(потребуется sudo-пароль на сервере)"
echo ""

ssh -t $SSH_OPTS "$DEPLOY_SERVER" "cd $DEPLOY_PATH && $GIT_CMD && sudo ./script/setup-nginx.sh"

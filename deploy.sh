#!/bin/bash
#
# Деплой на демо-стенд.
#   ./deploy.sh
#
# Перед запуском: git push origin main
# Локальный .env: DEPLOY_SERVER, DEPLOY_PATH, DEPLOY_GIT_SSH_KEY

set -e

cd "$(dirname "$0")"

if [ -f .env ]; then
  set -a
  # shellcheck source=/dev/null
  source .env
  set +a
fi

if [ -z "${DEPLOY_SERVER:-}" ]; then
  echo "❌ Укажите DEPLOY_SERVER в .env"
  exit 1
fi

if [ -z "${DEPLOY_PATH:-}" ]; then
  echo "❌ Укажите DEPLOY_PATH в .env"
  exit 1
fi

DEPLOY_BRANCH="${DEPLOY_BRANCH:-main}"

echo "🚀 Деплой на $DEPLOY_SERVER ($DEPLOY_PATH), ветка $DEPLOY_BRANCH"
if [ -n "${DEPLOY_GIT_SSH_KEY:-}" ]; then
  echo "🔑 Git SSH key (на сервере): $DEPLOY_GIT_SSH_KEY"
fi
echo ""

SSH_OPTS="-o ServerAliveInterval=30 -o ServerAliveCountMax=20"
COMPOSE_BASE="-f docker-compose.yml"

COMPOSE_CMD=$(ssh $SSH_OPTS "$DEPLOY_SERVER" "command -v docker-compose >/dev/null 2>&1 && echo docker-compose || echo 'docker compose'")
echo "📌 Compose на сервере: $COMPOSE_CMD $COMPOSE_BASE"
echo "---"

run() {
  echo "➡️  $1"
  ssh $SSH_OPTS "$DEPLOY_SERVER" "cd $DEPLOY_PATH && $2"
  echo "✅ OK"
  echo "---"
}

GIT_CMD="git fetch origin && git checkout \"${DEPLOY_BRANCH}\" && git pull origin \"${DEPLOY_BRANCH}\""
if [ -n "${DEPLOY_GIT_SSH_KEY:-}" ]; then
  GIT_CMD="export GIT_SSH_COMMAND=\"ssh -i ${DEPLOY_GIT_SSH_KEY} -o IdentitiesOnly=yes -o StrictHostKeyChecking=no\" && ${GIT_CMD}"
fi

run "Проверка: нет docker-compose.override.yml" \
  "test ! -f docker-compose.override.yml || (echo '❌ Удалите docker-compose.override.yml на сервере' && exit 1)"

run "Обновление кода" "$GIT_CMD"
run "Ревизия на сервере" "git rev-parse --short HEAD && git log -1 --oneline"

run "Сборка parser_sandbox" "$COMPOSE_CMD $COMPOSE_BASE --profile build-only build parser_sandbox"
run "Сборка web и sidekiq" "$COMPOSE_CMD $COMPOSE_BASE build web sidekiq"

run "Остановка контейнеров" "$COMPOSE_CMD $COMPOSE_BASE down"

run "Миграции (web_migrate)" "$COMPOSE_CMD $COMPOSE_BASE run --rm web_migrate"

run "Запуск всех сервисов" "$COMPOSE_CMD $COMPOSE_BASE up -d"

echo "⏳ Ожидание Elasticsearch..."
ssh $SSH_OPTS "$DEPLOY_SERVER" "cd $DEPLOY_PATH && for i in \$(seq 1 60); do \
  $COMPOSE_CMD $COMPOSE_BASE exec -T elasticsearch curl -sf 'http://localhost:9200/_cluster/health?wait_for_status=yellow&timeout=1s' >/dev/null && exit 0; \
  sleep 2; \
done; exit 1"
echo "✅ Elasticsearch ready"
echo "---"

WEB_PORT_REMOTE="${WEB_PORT:-3020}"
run "Healthcheck" "curl -sf http://127.0.0.1:${WEB_PORT_REMOTE}/up >/dev/null && echo 'GET /up → OK' || \
  (echo 'GET /up failed' && $COMPOSE_CMD $COMPOSE_BASE logs --tail=40 web && exit 1)"

echo "📊 Контейнеры:"
ssh $SSH_OPTS "$DEPLOY_SERVER" "cd $DEPLOY_PATH && $COMPOSE_CMD $COMPOSE_BASE ps"

echo ""
echo "🎉 Деплой завершён."
echo "   Сайт: http://${DEPLOY_SERVER#*@}:${WEB_PORT_REMOTE}/"
echo "   Логи: ./logs.sh -f sidekiq"

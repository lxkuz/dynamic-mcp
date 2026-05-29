#!/bin/bash

cd "$(dirname "$0")"

if [ -f .env ]; then
  set -a
  source .env
  set +a
fi

# shellcheck source=scripts/deploy_resolve.sh
source "$(dirname "$0")/scripts/deploy_resolve.sh"

set -e

TARGET="${1:-${DEPLOY_TARGET:-}}"
if [ -z "$TARGET" ]; then
  echo "❌ Укажите окружение первым аргументом или задайте DEPLOY_TARGET в .env"
  echo "   Пример: ./deploy.sh production   или   ./deploy.sh staging"
  exit 1
fi

if ! resolve_deploy_target "$TARGET"; then
  exit 1
fi

echo "🌍 Окружение: $TARGET"
echo "🌿 Ветка на сервере: ${DEPLOY_GIT_BRANCH}"
echo "🚀 Деплой на сервер: $DEPLOY_SERVER"
echo "📁 Рабочая директория: $DEPLOY_PATH"
if [ -n "${CLEANUP_PATH:-}" ]; then
  echo "🧹 CLEANUP_PATH (опционально): $CLEANUP_PATH"
fi
echo ""

SSH_OPTS="-o ServerAliveInterval=30 -o ServerAliveCountMax=20"

COMPOSE_CMD=$(ssh $SSH_OPTS "$DEPLOY_SERVER" "if command -v docker-compose >/dev/null 2>&1; then echo docker-compose; else echo 'docker compose'; fi")
echo "📌 Команда compose на сервере: $COMPOSE_CMD"
echo ""

run_ssh_command() {
  echo "➡️  Выполняю: $1"
  ssh $SSH_OPTS "$DEPLOY_SERVER" "$1"
  echo "✅ Команда выполнена успешно"
  echo "---"
}

echo "📋 Шаг 1: Переход в рабочую директорию"
run_ssh_command "cd $DEPLOY_PATH"

echo "📦 Шаг 2: Обновление кода"
run_ssh_command "cd $DEPLOY_PATH && git fetch origin && git checkout \"${DEPLOY_GIT_BRANCH}\" && git pull origin \"${DEPLOY_GIT_BRANCH}\""

echo "⬇️  Шаг 3: Остановка контейнеров"
run_ssh_command "cd $DEPLOY_PATH && $COMPOSE_CMD down"

echo "🔨 Шаг 4: Пересборка образов"
run_ssh_command "cd $DEPLOY_PATH && $COMPOSE_CMD build web web_migrate"

echo "🔄 Шаг 5: Миграции"
run_ssh_command "cd $DEPLOY_PATH && $COMPOSE_CMD run --rm web_migrate"

echo "⬆️  Шаг 6: Запуск"
set +e
ssh $SSH_OPTS "$DEPLOY_SERVER" "cd $DEPLOY_PATH && $COMPOSE_CMD up -d --build"
UP_EXIT=$?
set -e
if [ $UP_EXIT -ne 0 ]; then
  echo "❌ Запуск не удался. Логи web_migrate:"
  ssh $SSH_OPTS "$DEPLOY_SERVER" "cd $DEPLOY_PATH && $COMPOSE_CMD logs web_migrate"
  exit 1
fi
echo "✅ Контейнеры запущены"
echo "---"

if ! ssh $SSH_OPTS "$DEPLOY_SERVER" "cd $DEPLOY_PATH && $COMPOSE_CMD ps web 2>/dev/null | grep -q 'Up\|running'"; then
  echo "⚠️  Контейнер web не запущен. Логи:"
  ssh $SSH_OPTS "$DEPLOY_SERVER" "cd $DEPLOY_PATH && $COMPOSE_CMD logs web --tail=80"
  ssh $SSH_OPTS "$DEPLOY_SERVER" "cd $DEPLOY_PATH && $COMPOSE_CMD logs elasticsearch --tail=30"
fi

echo ""
echo "🎉 Деплой завершён"
run_ssh_command "cd $DEPLOY_PATH && $COMPOSE_CMD ps"

# Разрешение DEPLOY_SERVER / DEPLOY_PATH / CLEANUP_PATH по целевому окружению.
# Вызывать после source .env: resolve_deploy_target "production" (или staging).

resolve_deploy_target() {
  local raw="${1:-}"
  case "$raw" in
    production|prod)
      DEPLOY_SERVER="${DEPLOY_SERVER_PRODUCTION:-${DEPLOY_SERVER:-}}"
      DEPLOY_PATH="${DEPLOY_PATH_PRODUCTION:-${DEPLOY_PATH:-}}"
      CLEANUP_PATH="${CLEANUP_PATH_PRODUCTION:-}"
      DEPLOY_GIT_BRANCH="${DEPLOY_GIT_BRANCH_PRODUCTION:-master}"
      ;;
    staging|stage)
      DEPLOY_SERVER="${DEPLOY_SERVER_STAGING:-}"
      DEPLOY_PATH="${DEPLOY_PATH_STAGING:-}"
      CLEANUP_PATH="${CLEANUP_PATH_STAGING:-}"
      DEPLOY_GIT_BRANCH="${DEPLOY_GIT_BRANCH_STAGING:-develop}"
      ;;
    *)
      echo "❌ Укажите окружение: production (prod) | staging (stage)"
      echo "   Примеры: ./deploy.sh production   |   ./logs.sh --target staging"
      echo "   Или задайте DEPLOY_TARGET в .env (для deploy.sh — также первый аргумент)."
      return 1
      ;;
  esac

  if [ -z "$DEPLOY_SERVER" ] || [ -z "$DEPLOY_PATH" ]; then
    echo "❌ Для «$raw» задайте в .env:"
    case "$raw" in
      production|prod)
        echo "   DEPLOY_SERVER_PRODUCTION и DEPLOY_PATH_PRODUCTION"
        echo "   (запасной вариант: старые DEPLOY_SERVER и DEPLOY_PATH)"
        ;;
      *)
        echo "   DEPLOY_SERVER_STAGING и DEPLOY_PATH_STAGING"
        ;;
    esac
    return 1
  fi
  return 0
}

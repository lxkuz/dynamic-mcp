#!/bin/bash
#
# git pull с deploy-ключом (на сервере в ~/bookworm).
#
#   cd ~/bookworm && ./script/git-pull.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

if [ -f ".env" ]; then
  set -a
  # shellcheck source=/dev/null
  source ".env"
  set +a
fi

DEPLOY_GIT_SSH_KEY="${DEPLOY_GIT_SSH_KEY:-$HOME/.ssh/github_bookworm_deploy}"
BRANCH="${DEPLOY_GIT_BRANCH:-${DEPLOY_GIT_BRANCH_PRODUCTION:-main}}"

if [ ! -f "$DEPLOY_GIT_SSH_KEY" ]; then
  echo "❌ Ключ не найден: $DEPLOY_GIT_SSH_KEY"
  exit 1
fi

export GIT_SSH_COMMAND="ssh -i $DEPLOY_GIT_SSH_KEY -o IdentitiesOnly=yes -o StrictHostKeyChecking=no"

echo "git pull (ключ: $DEPLOY_GIT_SSH_KEY, ветка: $BRANCH)"
git fetch origin
git checkout "$BRANCH"
git pull origin "$BRANCH"

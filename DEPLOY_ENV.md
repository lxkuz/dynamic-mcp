# Переменные окружения и деплой

> Полная документация: **[docs/DEPLOY.md](docs/DEPLOY.md)**

## Локально

```bash
cp env.example .env
docker-compose build parser_sandbox web sidekiq
docker-compose up -d
```

## Демо-стенд

```bash
# .env локально:
# DEPLOY_SERVER=dockeruser@159.194.203.146
# DEPLOY_PATH=/home/dockeruser/bookworm
# DEPLOY_GIT_SSH_KEY=/home/dockeruser/.ssh/github_bookworm_deploy

git push origin main
./deploy.sh
```

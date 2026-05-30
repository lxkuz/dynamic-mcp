# Переменные окружения и деплой

> Полная документация: **[docs/DEPLOY.md](docs/DEPLOY.md)**

## Локально

```bash
cp env.example .env
docker-compose build parser_sandbox web sidekiq
docker-compose up -d
curl http://localhost:3020/up
```

## Деплой

```bash
# в .env локально:
# DEPLOY_SERVER_PRODUCTION=dockeruser@159.194.203.146
# DEPLOY_PATH_PRODUCTION=/home/dockeruser/bookworm
# DEPLOY_GIT_SSH_KEY=/home/dockeruser/.ssh/github_bookworm_deploy

git push origin main
./deploy.sh production
```

См. [docs/DEPLOY.md](docs/DEPLOY.md) — `.env` на сервере, nginx, troubleshooting.

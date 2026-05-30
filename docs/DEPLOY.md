# Деплой

**Демо-стенд:** https://bookworm.breget.tech  
**SSH:** `dockeruser@159.194.203.146` · **каталог:** `~/bookworm`

Шаблон переменных: [env.example](../env.example) — локальный `.env` и блок «Сервер» для `~/bookworm/.env`.

## Быстрый цикл

```bash
# локальный .env — DEPLOY_SERVER, DEPLOY_PATH, DEPLOY_BRANCH, DEPLOY_GIT_SSH_KEY
git push origin main
./deploy.sh
```

## Локальный `.env` для deploy

```bash
DEPLOY_SERVER=dockeruser@159.194.203.146
DEPLOY_PATH=/home/dockeruser/bookworm
DEPLOY_BRANCH=main
DEPLOY_GIT_SSH_KEY=/home/dockeruser/.ssh/github_bookworm_deploy

BOOKWORM_DOMAIN=bookworm.breget.tech
BOOKWORM_LETSENCRYPT_EMAIL=your@email.com
```

## Что делает `deploy.sh`

1. `git pull` на сервере (ключ `github_bookworm_deploy`)
2. `docker compose build` — parser_sandbox, web, sidekiq
3. `down` → `web_migrate` → `up -d`
4. ожидание Elasticsearch → `GET /up`

## `.env` на сервере

| Переменная | Пример |
|------------|--------|
| `SECRET_KEY_BASE` | `openssl rand -hex 64` |
| `WEB_PORT` | `3020` |
| `PUBLIC_HOST` | `bookworm.breget.tech` |
| `PUBLIC_SCHEME` | `https` |
| `DEEPSEEK_API_KEY` | для AI-импорта |
| `BOOK_IMPORT_HOST_WORKDIR` | `/home/dockeruser/bookworm/tmp/book-import` |
| `MCP_ALLOWED_ORIGINS` | `bookworm.breget.tech,localhost,127.0.0.1` |

`DEPLOY_*` на сервере не нужны.

## HTTPS (nginx + Let's Encrypt)

Скрипт создаёт **только** `/etc/nginx/sites-available/bookworm.breget.tech.conf` — другие vhost (`ftw.breget.tech`, `psychologist.breget.tech`) не трогает.

```bash
./script/setup-nginx-remote.sh
# или на сервере: sudo ./script/setup-nginx.sh
```

После nginx:

```bash
curl https://bookworm.breget.tech/up
docker compose up -d web   # на сервере, если меняли PUBLIC_*
```

## Скрипты

| Скрипт | Назначение |
|--------|------------|
| `./deploy.sh` | Деплой |
| `./logs.sh -f sidekiq` | Логи |
| `./restart.sh` | Рестарт без rebuild |
| `./script/git-pull.sh` | Pull на сервере |
| `./script/setup-nginx-remote.sh` | nginx + SSL |

## Git на сервере

```bash
cd ~/bookworm && ./script/git-pull.sh
```

## Push с Mac (если порт 22 заблокирован)

```bash
GIT_SSH_COMMAND="ssh -p 443 -o Hostname=ssh.github.com" git push origin main
```

Или в `~/.ssh/config`:

```
Host github.com
  Hostname ssh.github.com
  Port 443
  User git
```

## Troubleshooting

| Проблема | Решение |
|----------|---------|
| `git pull` Permission denied | `DEPLOY_GIT_SSH_KEY`, ключ в GitHub |
| AI: docker permission denied | `docker.sock` в sidekiq, группа `docker` |
| Sandbox не видит файлы | `BOOK_IMPORT_HOST_WORKDIR` — абсолютный путь на хосте |
| Healthcheck failed сразу после deploy | Подождать 10–20 с, web стартует после ES |
| MCP не открывается | `proxy_buffering off` в nginx |

На сервере используется `docker compose` (v2); локально в репозитории — `docker-compose` (с дефисом).

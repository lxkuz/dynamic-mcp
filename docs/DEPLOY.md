# Деплoy

Один **демо-стенд**: `dockeruser@159.194.203.146`, каталог `~/bookworm`.

## Быстрый старт

1. Закоммитьте и **запушьте** в `origin/main`.
2. В локальном `.env`:

```bash
DEPLOY_SERVER=dockeruser@159.194.203.146
DEPLOY_PATH=/home/dockeruser/bookworm
DEPLOY_BRANCH=main
DEPLOY_GIT_SSH_KEY=/home/dockeruser/.ssh/github_bookworm_deploy
```

3. Деплой:

```bash
./deploy.sh
```

## Что делает deploy.sh

По SSH на сервере:

1. `git pull` (с deploy-ключом `github_bookworm_deploy`)
2. `docker-compose build` (parser_sandbox, web, sidekiq)
3. `down` → `web_migrate` → `up -d`
4. ожидание Elasticsearch + `GET /up`

## `.env` на сервере (`~/bookworm/.env`)

| Переменная | Обязательно | Пример |
|------------|-------------|--------|
| `SECRET_KEY_BASE` | да | `bin/rails secret` |
| `WEB_PORT` | нет | `3020` |
| `DEEPSEEK_API_KEY` | для AI | `sk-...` |
| `BOOK_IMPORT_HOST_WORKDIR` | для AI | `/home/dockeruser/bookworm/tmp/book-import` |
| `PUBLIC_HOST` | для MCP URLs | IP или домен |

## Git на сервере

```bash
cd ~/bookworm
./script/git-pull.sh
```

Или вручную:

```bash
export GIT_SSH_COMMAND='ssh -i ~/.ssh/github_bookworm_deploy -o IdentitiesOnly=yes -o StrictHostKeyChecking=no'
git pull origin main
```

## Скрипты

| Скрипт | Назначение |
|--------|------------|
| `./deploy.sh` | Полный деплoy |
| `./logs.sh -f sidekiq` | Логи |
| `./restart.sh` | down + up без rebuild |
| `./script/git-pull.sh` | На сервере: pull с deploy-ключом |

## Первичная настройка сервера

```bash
cd ~
git clone git@github.com:lxkuz/dynamic-mcp.git bookworm
cd bookworm
cp env.example .env
mkdir -p tmp/book-import
docker-compose build parser_sandbox web sidekiq
docker-compose up -d
```

## Nginx + HTTPS

Скрипт добавляет **только** vhost `bookworm.breget.tech` — другие сайты (например `ftw.breget.tech`) не затрагиваются.

**Перед запуском:** DNS A-запись `bookworm.breget.tech` → IP сервера, приложение слушает `WEB_PORT=3020`.

В `.env` на сервере:

```bash
BOOKWORM_DOMAIN=bookworm.breget.tech
BOOKWORM_LETSENCRYPT_EMAIL=your@email.com
WEB_PORT=3020
```

С локальной машины (после `git push`):

```bash
./script/setup-nginx-remote.sh
```

Или на сервере:

```bash
cd ~/bookworm
sudo ./script/setup-nginx.sh
```

После успеха обновите `~/bookworm/.env`:

```bash
PUBLIC_HOST=bookworm.breget.tech
PUBLIC_SCHEME=https
MCP_ALLOWED_ORIGINS=bookworm.breget.tech,localhost,127.0.0.1
```

И перезапустите web:

```bash
docker-compose up -d web
```

Проверка:

```bash
curl -sf https://bookworm.breget.tech/up
```

MCP: `https://bookworm.breget.tech/books/{uid}/mcp/sse`

## Nginx (ручная настройка)

```nginx
location / {
  proxy_pass http://127.0.0.1:3020;
  proxy_http_version 1.1;
  proxy_set_header Host $host;
  proxy_set_header X-Forwarded-Proto $scheme;
  proxy_set_header Connection "";
  proxy_buffering off;
  proxy_read_timeout 600s;
}
```

## Проверка

```bash
curl http://159.194.203.146:3020/up
./logs.sh -f web
```

## Troubleshooting

| Проблема | Решение |
|----------|---------|
| `git pull` — Permission denied | Ключ `~/.ssh/github_bookworm_deploy` в GitHub |
| AI: docker permission denied | mount `docker.sock`, группа docker |
| Sandbox не видит файлы | `BOOK_IMPORT_HOST_WORKDIR` — абсолютный путь на хосте |
| Старый код | Сначала `git push`, потом `./deploy.sh` |

На сервере `deploy.sh` сам выбирает `docker-compose` или `docker compose`.

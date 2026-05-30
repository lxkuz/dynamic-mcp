# Деплой

Production-сервер: `dockeruser@159.194.203.146`, каталог **`~/bookworm`**.

## Быстрый старт (с локальной машины)

1. Закоммитьте и **запушьте** изменения в `origin/main`.
2. Настройте локальный `.env` (см. ниже).
3. Запустите:

```bash
./deploy.sh production
```

Скрипт по SSH:

1. `git pull` на сервере (с deploy-ключом)
2. `docker-compose build` (web, sidekiq, parser_sandbox)
3. `docker-compose down` → `web_migrate` → `up -d`
4. healthcheck `GET /up`

## Локальный `.env` для деплоя

```bash
DEPLOY_TARGET=production

DEPLOY_SERVER_PRODUCTION=dockeruser@159.194.203.146
DEPLOY_PATH_PRODUCTION=/home/dockeruser/bookworm
DEPLOY_GIT_BRANCH_PRODUCTION=main

# Путь к ключу НА СЕРВЕРЕ (используется в git pull по SSH)
DEPLOY_GIT_SSH_KEY=/home/dockeruser/.ssh/github_bookworm_deploy
```

## `.env` на сервере (`~/bookworm/.env`)

Создайте один раз на сервере:

| Переменная | Обязательно | Пример |
|------------|-------------|--------|
| `SECRET_KEY_BASE` | да | `bin/rails secret` |
| `WEB_PORT` | нет | `3020` |
| `DEEPSEEK_API_KEY` | для AI | `sk-...` |
| `AI_IMPORT_ENABLED` | нет | `true` |
| `BOOK_IMPORT_HOST_WORKDIR` | да для AI | `/home/dockeruser/bookworm/tmp/book-import` |
| `PUBLIC_HOST` | для MCP URLs | ваш домен |
| `PUBLIC_SCHEME` | | `https` |

Elasticsearch только внутри compose: `ELASTICSEARCH_URL=http://elasticsearch:9200`.

Sidekiq монтирует `/var/run/docker.sock` — пользователь `root` в контейнере для запуска sandbox.

## Git на сервере (deploy-ключ)

На сервере ключ: `~/.ssh/github_bookworm_deploy`

Pull вручную на сервере:

```bash
cd ~/bookworm
./script/git-pull.sh
```

Или:

```bash
export GIT_SSH_COMMAND='ssh -i ~/.ssh/github_bookworm_deploy -o IdentitiesOnly=yes -o StrictHostKeyChecking=no'
git pull origin main
```

`deploy.sh` экспортирует `GIT_SSH_COMMAND` автоматически, если задан `DEPLOY_GIT_SSH_KEY`.

## Скрипты

| Скрипт | Назначение |
|--------|------------|
| `./deploy.sh production` | Полный деплой |
| `./logs.sh production -f sidekiq` | Логи |
| `./restart.sh production` | down + up без rebuild |
| `./script/git-pull.sh` | На **сервере**: pull с deploy-ключом |

Окружения: `production` / `prod`, `staging` / `stage` (через `DEPLOY_*_STAGING` в `.env`).

## Первичная настройка сервера

```bash
# на сервере
cd ~
git clone git@github.com:lxkuz/dynamic-mcp.git bookworm
cd bookworm
cp env.example .env
# отредактировать .env

mkdir -p tmp/book-import
docker-compose build parser_sandbox web sidekiq
docker-compose up -d
```

Убедитесь, что пользователь `dockeruser` в группе `docker` и deploy-ключ добавлен в GitHub (read-only).

## Nginx

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

MCP: `https://your-domain/books/{uid}/mcp/sse`

## Проверка после деплоя

```bash
curl -sf http://159.194.203.146:3020/up
ssh dockeruser@159.194.203.146 'cd ~/bookworm && docker-compose ps'
```

## Elasticsearch

```bash
ssh dockeruser@159.194.203.146
cd ~/bookworm
docker-compose exec elasticsearch curl -s 'http://localhost:9200/_cat/indices?v'
```

При смене major-версии ES:

```bash
docker-compose down
docker volume rm dynamic-mcp_es_data   # уточните: docker volume ls | grep es
docker-compose up -d
```

## Troubleshooting

| Проблема | Решение |
|----------|---------|
| `git pull` на сервере — Permission denied | Проверьте `DEPLOY_GIT_SSH_KEY` и ключ в GitHub |
| AI-импорт: docker permission denied | `docker.sock` mount, группа docker на хосте |
| Sandbox не находит файлы | Задайте `BOOK_IMPORT_HOST_WORKDIR` = абсолютный путь на хосте |
| ES не healthy | Подождите 2 мин, `docker-compose logs elasticsearch` |
| Старый код после deploy | Сначала `git push` с локальной машины |

## Важно

- В репозитории команды compose — **`docker-compose`** (с дефисом). На сервере `deploy.sh` автоматически выбирает `docker-compose` или `docker compose`.
- Не храните `.env` с секретами в git.
- Перед деплоем всегда пушьте в `origin` — на сервере только `git pull`, не rsync.

# Переменные окружения и деплой

Запуск **только через Docker Compose** (`docker-compose`, не `docker compose`).

## Локально

```bash
cp env.example .env
# Заполните SECRET_KEY_BASE: bin/rails secret

docker-compose build
docker-compose up -d
```

API: `http://localhost:3020` (или порт из `WEB_PORT`).

Проверка:

```bash
curl http://localhost:3020/up
curl -F "file=@spec/fixtures/sample.fb2" http://localhost:3020/api/v1/books
```

## `.env` на сервере (`$DEPLOY_PATH/.env`)

| Переменная | Обязательно | Описание |
|------------|-------------|----------|
| `SECRET_KEY_BASE` | да | `bin/rails secret` |
| `WEB_PORT` | нет | Порт на хосте, по умолчанию `3020` |
| `ELASTICSEARCH_URL` | нет | В compose: `http://elasticsearch:9200` |
| `RAILS_LOG_LEVEL` | нет | `info` / `debug` |

Elasticsearch **не пробрасывается на хост** — только `http://elasticsearch:9200` внутри сети compose.

Данные (SQLite, загруженные FB2): volume `app_storage` → `/rails/storage`.

## Деплой с локальной машины

В `.env` на **локальной** машине:

| Переменная | Описание |
|------------|----------|
| `DEPLOY_TARGET` | По умолчанию для скриптов: `production` / `staging` |
| `DEPLOY_SERVER_PRODUCTION` | SSH, например `user@host` |
| `DEPLOY_PATH_PRODUCTION` | Каталог проекта на сервере |
| `DEPLOY_GIT_BRANCH_PRODUCTION` | Ветка, по умолчанию `main` |
| `DEPLOY_SERVER_STAGING` | SSH staging |
| `DEPLOY_PATH_STAGING` | Каталог staging |

```bash
./deploy.sh production
./logs.sh production -f web
./restart.sh production
```

Скрипт деплоя: `git pull` → `docker-compose down` → `build` → `web_migrate` → `up -d`.

Nginx (один upstream на `WEB_PORT`):

```nginx
location / {
  proxy_pass http://127.0.0.1:3020;
  proxy_http_version 1.1;
  proxy_set_header Host $host;
  proxy_set_header X-Forwarded-Proto $scheme;
  proxy_set_header Connection "";
  proxy_buffering off;          # важно для MCP SSE
  proxy_read_timeout 600s;
}
```

MCP для книги: `https://your-domain/books/{uid}/mcp/sse`

## Elasticsearch на сервере

```bash
cd $DEPLOY_PATH
docker-compose exec elasticsearch curl -s "http://localhost:9200/_cat/indices?v"
docker-compose exec elasticsearch curl -s "http://localhost:9200/dynamic_mcp_books/_count"
```

При смене major-версии ES:

```bash
docker-compose down
docker volume rm dynamic-mcp_es_data   # имя уточните: docker volume ls | grep es
docker-compose up -d
```

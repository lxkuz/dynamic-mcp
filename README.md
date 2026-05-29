# dynamic-mcp

REST API для FB2 и PDF: оглавление, страницы, полнотекстовый поиск (Elasticsearch). См. [docs/MVP.md](docs/MVP.md).

**Запуск только через Docker Compose** (по образцу [armchair-expert](https://github.com/) — `web_migrate` + `web` + `elasticsearch`).

## Быстрый старт

```bash
cp env.example .env
# SECRET_KEY_BASE=$(bin/rails secret)  — или сгенерируйте один раз локально

docker-compose build
docker-compose up -d
```

Дождитесь healthcheck Elasticsearch (~1–2 мин при первом старте).

В браузере: **http://localhost:3020/** — форма загрузки FB2 или PDF.

После загрузки:
- REST API по `uid` книги
- **MCP SSE:** `http://localhost:3020/books/{uid}/mcp/sse` (тот же порт, что и сайт)
- **MCP docs:** `http://localhost:3020/books/{uid}/mcp`

```bash
curl http://localhost:3020/up
curl -F "file=@spec/fixtures/sample.fb2" http://localhost:3020/api/v1/books
# в ответе возьмите uid, затем:
curl http://localhost:3020/api/v1/books/{uid}/toc
curl "http://localhost:3020/api/v1/books/{uid}/search?q=elasticsearch"
curl http://localhost:3020/books/{uid}/mcp
```

## API

| Метод | Путь |
|-------|------|
| POST | `/api/v1/books` — загрузка `.fb2` или `.pdf` (в ответе `uid`, `mcp_documentation_url`) |
| GET | `/api/v1/books/:uid` |
| GET | `/books/:uid/mcp` — документация MCP для агента |
| GET | `/api/v1/books/:uid/toc` |
| GET | `/api/v1/books/:uid/toc/search?q=` |
| GET | `/api/v1/books/:uid/pages/:number` |
| GET | `/api/v1/books/:uid/search?q=` |

## Команды

```bash
docker-compose logs -f web
docker-compose run --rm web_migrate
docker-compose down
```

## Деплой

См. [DEPLOY_ENV.md](DEPLOY_ENV.md). С локальной машины: `./deploy.sh production` (после настройки `DEPLOY_*` в `.env`).

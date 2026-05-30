# dynamic-mcp

REST API для FB2 и PDF: оглавление, страницы, полнотекстовый поиск (Elasticsearch). Каждая книга — свой **MCP** endpoint для AI-агентов.

**Демо-стенд:** https://bookworm.breget.tech

**Документация:** [docs/README.md](docs/README.md)

**Запуск только через Docker Compose** — `web_migrate` + `web` + `sidekiq` + `redis` + `elasticsearch`.

## Быстрый старт (локально)

```bash
cp env.example .env
# отредактируйте .env — см. комментарии в env.example
# SECRET_KEY_BASE=$(bin/rails secret)

docker-compose build parser_sandbox web sidekiq
docker-compose up -d
```

Дождитесь healthcheck Elasticsearch (~1–2 мин при первом старте).

В браузере: **http://localhost:3020/** — форма загрузки FB2 или PDF.

После загрузки импорт идёт **в фоне (Sidekiq)**. Страница `/uploads/{uid}` показывает прогресс.

| | Локально | Демо-стенд |
|--|----------|------------|
| Сайт | http://localhost:3020 | https://bookworm.breget.tech |
| MCP SSE | `http://localhost:3020/books/{uid}/mcp/sse` | `https://bookworm.breget.tech/books/{uid}/mcp/sse` |
| MCP docs | `/books/{uid}/mcp` | то же на домене |

```bash
curl http://localhost:3020/up
curl -F "file=@book.pdf" http://localhost:3020/api/v1/books
curl http://localhost:3020/api/v1/books/{uid}/toc
curl "http://localhost:3020/api/v1/books/{uid}/search?q=буровой"
```

## Cursor MCP

В `~/.cursor/mcp.json`:

```json
{
  "mcpServers": {
    "dm": {
      "url": "https://bookworm.breget.tech/books/{uid}/mcp/sse"
    }
  }
}
```

Подробнее: [docs/MCP.md](docs/MCP.md)

## API

| Метод | Путь |
|-------|------|
| POST | `/api/v1/books` — загрузка файла |
| GET | `/api/v1/books/:uid` |
| GET | `/books/:uid/mcp` — документация MCP |
| GET | `/api/v1/books/:uid/toc` |
| GET | `/api/v1/books/:uid/pages/:number` |
| GET | `/api/v1/books/:uid/pages?from=1&to=3` |
| GET | `/api/v1/books/:uid/sections/:id` |
| GET | `/api/v1/books/:uid/search?q=` |
| GET | `/uploads/:uid/status` — JSON статус импорта |

Полный список: [docs/API.md](docs/API.md)

## AI-импорт (DeepSeek + ActiveHarness)

Без `DEEPSEEK_API_KEY` используется **legacy**-парсер (`Fb2`/`Pdf`).

```bash
AI_IMPORT_ENABLED=true
DEEPSEEK_API_KEY=sk-...
```

Документация: [docs/AI_IMPORT.md](docs/AI_IMPORT.md)

## Команды

```bash
docker-compose logs -f web
docker-compose logs -f sidekiq
docker-compose run --rm web_migrate
docker-compose down
```

## Демо-стенд: деплой и HTTPS

Шаблон переменных: **`env.example`** (локальный `.env` и отличия для сервера).

```bash
git push origin main
./deploy.sh
./script/setup-nginx-remote.sh   # один раз, нужен sudo на сервере
```

Логи: `./logs.sh -f sidekiq` · Рестарт: `./restart.sh`

Подробнее: [docs/DEPLOY.md](docs/DEPLOY.md)

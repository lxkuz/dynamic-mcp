# dynamic-mcp

REST API для FB2 и PDF: оглавление, страницы, полнотекстовый поиск (Elasticsearch).

**Документация:** [docs/README.md](docs/README.md) — архитектура, AI-импорт, MCP, деплoy.

**Запуск только через Docker Compose** — `web_migrate` + `web` + `sidekiq` + `redis` + `elasticsearch`.

## Быстрый старт

```bash
cp env.example .env
# SECRET_KEY_BASE=$(bin/rails secret)  — или сгенерируйте один раз локально

docker-compose build parser_sandbox web sidekiq
docker-compose up -d
```

Дождитесь healthcheck Elasticsearch (~1–2 мин при первом старте).

В браузере: **http://localhost:3020/** — форма загрузки FB2 или PDF.

После загрузки импорт идёт **в фоне (Sidekiq)**. Страница `/uploads/{uid}` показывает прогресс.

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
| POST | `/api/v1/books` — загрузка файла книги (любой формат при AI-импорте) |
| GET | `/api/v1/books/:uid` |
| GET | `/books/:uid/mcp` — документация MCP для агента |
| GET | `/api/v1/books/:uid/toc` |
| GET | `/api/v1/books/:uid/toc/search?q=` |
| GET | `/api/v1/books/:uid/pages/:number` |
| GET | `/api/v1/books/:uid/pages?from=1&to=3` — диапазон страниц |
| GET | `/api/v1/books/:uid/sections/:id` — секция оглавления |
| GET | `/api/v1/books/:uid/search?q=` (`context_chars` опционально) |

| GET | `/uploads/:uid/status` — JSON статус импорта |

## AI-импорт (DeepSeek + ActiveHarness)

По умолчанию без `DEEPSEEK_API_KEY` используется **legacy**-парсер (`Fb2`/`Pdf`).

```bash
# .env
AI_IMPORT_ENABLED=true
DEEPSEEK_API_KEY=sk-...
```

План и архитектура: [docs/AI_IMPORT.md](docs/AI_IMPORT.md) (операционная документация), [docs/AI_IMPORT_PLAN.md](docs/AI_IMPORT_PLAN.md) (исходный план)

## Команды

```bash
docker-compose logs -f web
docker-compose logs -f sidekiq
docker-compose run --rm web_migrate
docker-compose down
```

## Деплой (демо-стенд)

См. [docs/DEPLOY.md](docs/DEPLOY.md):

```bash
# DEPLOY_SERVER, DEPLOY_PATH, DEPLOY_GIT_SSH_KEY в .env
git push origin main
./deploy.sh
```

Логи: `./logs.sh -f sidekiq` · Рестарт: `./restart.sh`

### HTTPS (nginx)

```bash
# BOOKWORM_LETSENCRYPT_EMAIL в .env, DNS A → сервер
./script/setup-nginx-remote.sh
```

См. [docs/DEPLOY.md](docs/DEPLOY.md#nginx--https).

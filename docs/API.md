# REST API

## Базовые URL

| Окружение | URL |
|-----------|-----|
| Локально | `http://localhost:3020` |
| Демо-стенд | `https://bookworm.breget.tech` |

## Загрузка книги

```http
POST /api/v1/books
Content-Type: multipart/form-data

file=@book.pdf
```

```bash
curl -F "file=@book.pdf" https://bookworm.breget.tech/api/v1/books
```

Ответ:

```json
{
  "uid": "abc123...",
  "status": "processing",
  "upload_url": "/uploads/abc123..."
}
```

Статус импорта: `GET /uploads/:uid/status`

## Endpoints

| Метод | Путь | Описание |
|-------|------|----------|
| GET | `/up` | Healthcheck |
| GET | `/api/v1/books/:uid` | Метаданные |
| GET | `/api/v1/books/:uid/toc` | Оглавление |
| GET | `/api/v1/books/:uid/toc/search?q=` | Поиск по заголовкам |
| GET | `/api/v1/books/:uid/pages/:number` | Страница |
| GET | `/api/v1/books/:uid/pages?from=1&to=3` | Диапазон (макс. 20) |
| GET | `/api/v1/books/:uid/sections/:id` | Секция |
| GET | `/api/v1/books/:uid/search?q=` | Полнотекстовый поиск |
| GET | `/books/:uid/mcp` | Документация MCP |

Параметр `context_chars` в search — размер фрагмента вокруг совпадения.

## Форматы

| Формат | Страницы | Оглавление |
|--------|----------|------------|
| PDF | физические 1..N | `page_start` / `page_end` |
| FB2 | виртуальные (~1800 символов) | дерево `<section>` |

## Примеры

```bash
curl https://bookworm.breget.tech/up
curl https://bookworm.breget.tech/api/v1/books/{uid}/toc
curl "https://bookworm.breget.tech/api/v1/books/{uid}/search?q=буровой&context_chars=600"
curl https://bookworm.breget.tech/api/v1/books/{uid}/pages/30
```

## UI

- `/` — загрузка книги
- `/uploads/:uid` — прогресс AI-импорта

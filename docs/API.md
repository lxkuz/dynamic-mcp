# REST API

Базовый URL: `http://localhost:3020` (или `WEB_PORT` / домен на production).

## Загрузка книги

```http
POST /api/v1/books
Content-Type: multipart/form-data

file=@book.pdf
```

Ответ (202/201):

```json
{
  "uid": "abc123...",
  "status": "processing",
  "upload_url": "/uploads/abc123..."
}
```

Импорт асинхронный — следите за статусом:

```http
GET /uploads/:uid/status
```

## Книга

| Метод | Путь | Описание |
|-------|------|----------|
| GET | `/api/v1/books/:uid` | Метаданные, status |
| GET | `/api/v1/books/:uid/toc` | Дерево оглавления |
| GET | `/api/v1/books/:uid/toc/search?q=` | Поиск по заголовкам секций |
| GET | `/api/v1/books/:uid/pages/:number` | Одна страница |
| GET | `/api/v1/books/:uid/pages?from=1&to=3` | Диапазон (макс. 20) |
| GET | `/api/v1/books/:uid/sections/:id` | Текст секции |
| GET | `/api/v1/books/:uid/search?q=` | Полнотекстовый поиск (Elasticsearch) |

Параметр `context_chars` для search — размер фрагмента вокруг совпадения.

## Health

```http
GET /up
```

## Форматы

| Формат | Страницы | Оглавление |
|--------|----------|------------|
| PDF | физические 1..N | секции с page_start/page_end |
| FB2 | виртуальные (~1800 символов) | дерево `<section>` |

## Примеры

```bash
curl -F "file=@book.pdf" http://localhost:3020/api/v1/books
curl http://localhost:3020/api/v1/books/{uid}/toc
curl "http://localhost:3020/api/v1/books/{uid}/search?q=буровой&context_chars=600"
curl http://localhost:3020/api/v1/books/{uid}/pages/1
```

## UI

- `/` — форма загрузки
- `/uploads/:uid` — прогресс AI-импорта (polling status)

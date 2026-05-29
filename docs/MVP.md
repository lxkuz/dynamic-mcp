# Dynamic MCP — MVP

## MCP

Один процесс **web** (Rails + Puma). MCP встроен в middleware — **тот же порт**, что и сайт.

| URL | Назначение |
|-----|------------|
| `GET /books/:uid/mcp` | HTML-документация |
| `GET /books/:uid/mcp/sse` | SSE для MCP-клиента |
| `POST /books/:uid/mcp/messages` | JSON-RPC |

Каждая книга — свой MCP endpoint (свой набор tools), но **один сервер для деплоя**.

Nginx: один `proxy_pass` на `WEB_PORT`, для SSE отключить буферизацию (`proxy_buffering off`).

## Идентификация

Публичный **`uid`** книги (`SecureRandom.urlsafe_base64(32)`).

## REST API

| Метод | Путь |
|-------|------|
| POST | `/api/v1/books` |
| GET | `/api/v1/books/:uid` |
| GET | `/api/v1/books/:uid/toc` |
| GET | `/api/v1/books/:uid/toc/search?q=` |
| GET | `/api/v1/books/:uid/pages/:number` |
| GET | `/api/v1/books/:uid/search?q=` |

## Стек

Rails 8, SQLite, Elasticsearch, fast-mcp (Rack middleware), docker-compose

## Форматы

| Формат | Оглавление | Страницы |
|--------|------------|----------|
| FB2 | дерево `<section>` | виртуальные (~1800 символов) |
| PDF | одна секция (MVP) | физические страницы PDF |

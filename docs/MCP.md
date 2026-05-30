# MCP (Model Context Protocol)

Каждая книга (`status: ready`) получает свой MCP endpoint.

## URLs

| | Локально | Демо-стенд |
|--|----------|------------|
| SSE | `http://localhost:3020/books/{uid}/mcp/sse` | `https://bookworm.breget.tech/books/{uid}/mcp/sse` |
| Docs | `/books/{uid}/mcp` | то же на домене |
| JSON-RPC | `POST /books/{uid}/mcp/messages` | то же |

## Cursor (`~/.cursor/mcp.json`)

```json
{
  "mcpServers": {
    "dm": {
      "url": "https://bookworm.breget.tech/books/YOUR_BOOK_UID/mcp/sse"
    }
  }
}
```

После смены `uid` или URL: Settings → MCP → Reload.

## Tools

| Tool | Описание |
|------|----------|
| `book_info` | Метаданные, page_count, recommended_tools |
| `list_toc` | Дерево оглавления |
| `search_toc` | Поиск по заголовкам |
| `get_page` | Текст страницы (`number`: 1..N) |
| `get_pages` | Диапазон страниц (`from`, `to`, макс. 20) |
| `get_section` | Текст секции по `id` из `list_toc` |
| `search_fulltext` | Elasticsearch (`context_chars` опционально) |

В ответах tools — ключ **`text`**, не `content`.

## Проверка

```bash
curl https://bookworm.breget.tech/up
ruby script/mcp_probe.rb https://bookworm.breget.tech/books/{uid}/mcp/sse
```

## Nginx

На демо-стенде vhost настроен скриптом `script/setup-nginx.sh`. Для SSE обязательно:

- `proxy_buffering off`
- `proxy_read_timeout 600s`

Подробнее: [DEPLOY.md](DEPLOY.md)

## Код

- `app/middleware/mcp/book_middleware.rb`
- `app/services/mcp/tools.rb`
- `config/initializers/mcp.rb`

MCP доступен только при `book.ready?`.

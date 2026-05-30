# MCP (Model Context Protocol)

Каждая **готовая** книга (`status: ready`) получает свой MCP endpoint на том же порту, что и сайт.

## URLs

| URL | Назначение |
|-----|------------|
| `GET /books/:uid/mcp` | HTML-документация для агента |
| `GET /books/:uid/mcp/sse` | SSE transport (Cursor, Claude Desktop, …) |
| `POST /books/:uid/mcp/messages` | JSON-RPC |

Пример локально:

```
http://localhost:3020/books/{uid}/mcp/sse
```

## Конфиг Cursor (`~/.cursor/mcp.json`)

```json
{
  "mcpServers": {
    "dm": {
      "url": "http://localhost:3020/books/YOUR_BOOK_UID/mcp/sse"
    }
  }
}
```

После смены uid перезагрузите MCP в Settings → MCP → Reload.

## Tools

| Tool | Описание |
|------|----------|
| `book_info` | title, author, page_count, format, recommended_tools |
| `list_toc` | Дерево оглавления (id, title, path, page_start/end) |
| `search_toc` | Поиск по заголовкам |
| `get_page` | Текст одной страницы |
| `get_pages` | Диапазон страниц (from, to, макс. 20) |
| `get_section` | Полный текст секции по id из list_toc |
| `search_fulltext` | Elasticsearch, параметр context_chars |

**Важно:** в ответах tools используется ключ `text`, не `content` (ограничение fast-mcp).

## Nginx (production)

Для SSE отключите буферизацию:

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

## Реализация

- `app/middleware/mcp/book_middleware.rb` — маршрутизация по uid
- `app/services/mcp/tools.rb` — регистрация tools
- `config/initializers/mcp.rb` — имя сервера, версия
- `app/presenters/mcp/documentation_presenter.rb` — HTML docs

MCP доступен только когда `book.ready?`.

## Проверка

```bash
ruby script/mcp_probe.rb http://localhost:3020/books/{uid}/mcp/sse
```

# Документация dynamic-mcp

Сервис загрузки книг (FB2, PDF и др.), их разбора, индексации в Elasticsearch и выдачи через **REST API** и **MCP** для AI-агентов.

## Демо-стенд

| | |
|--|--|
| URL | https://bookworm.breget.tech |
| Сервер | `dockeruser@159.194.203.146`, каталог `~/bookworm` |
| MCP | `https://bookworm.breget.tech/books/{uid}/mcp/sse` |

## С чего начать

| Задача | Документ |
|--------|----------|
| Переменные окружения | [../env.example](../env.example) |
| Понять, как устроена система | [ARCHITECTURE.md](ARCHITECTURE.md) |
| AI-импорт (агенты, скрипты, итерации) | [AI_IMPORT.md](AI_IMPORT.md) |
| REST API | [API.md](API.md) |
| MCP для Cursor | [MCP.md](MCP.md) |
| Локальный запуск | [../README.md](../README.md) |
| Деплой и HTTPS | [DEPLOY.md](DEPLOY.md) |
| Исходный план AI-импорта | [AI_IMPORT_PLAN.md](AI_IMPORT_PLAN.md) |
| MVP-ограничения | [MVP.md](MVP.md) |

## Что происходит после загрузки файла

1. Upload на `/` → `Book` со статусом `processing`.
2. **Sidekiq** → `ImportBookJob`.
3. **Orchestrator** (AI или legacy) → `ParsedDocument`.
4. SQLite + **Elasticsearch**.
5. `status: ready` → REST и MCP по `/books/{uid}/…`.

Подробности: [ARCHITECTURE.md](ARCHITECTURE.md), [AI_IMPORT.md](AI_IMPORT.md).

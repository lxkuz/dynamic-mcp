# Документация dynamic-mcp

Сервис загрузки книг (FB2, PDF и др.), их разбора, индексации в Elasticsearch и выдачи через **REST API** и **MCP** (Model Context Protocol) для AI-агентов.

## С чего начать

| Задача | Документ |
|--------|----------|
| Понять, как устроена система | [ARCHITECTURE.md](ARCHITECTURE.md) |
| Как работает AI-импорт (агенты, скрипты, итерации) | [AI_IMPORT.md](AI_IMPORT.md) |
| REST API и форматы | [API.md](API.md) |
| MCP для Cursor / Claude | [MCP.md](MCP.md) |
| Локальный запуск | [../README.md](../README.md) |
| Деплой на сервер | [DEPLOY.md](DEPLOY.md) |
| Исходный план AI-импорта (исторический) | [AI_IMPORT_PLAN.md](AI_IMPORT_PLAN.md) |
| MVP-ограничения | [MVP.md](MVP.md) |

## Кратко: что происходит после загрузки файла

1. Пользователь загружает файл на `/` → создаётся `Book` со статусом `processing`.
2. **Sidekiq** ставит `ImportBookJob` в очередь `book_imports`.
3. **Orchestrator** (AI или legacy) получает `ParsedDocument` — title, author, sections, pages.
4. Данные пишутся в **SQLite**, текст индексируется в **Elasticsearch**.
5. Книга переходит в `ready` → доступны REST и MCP по `/books/{uid}/…`.

Подробности — в [ARCHITECTURE.md](ARCHITECTURE.md) и [AI_IMPORT.md](AI_IMPORT.md).

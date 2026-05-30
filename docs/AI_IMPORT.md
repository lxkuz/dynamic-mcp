# AI-импорт книг

Подробное описание конвейера, который заменяет жёстко зашитые `Fb2::Importer` / `Pdf::Importer` на **генерацию Ruby-парсера** через LLM.

## Когда включается

AI-импорт активен, если одновременно:

```ruby
AI_IMPORT_ENABLED=true   # по умолчанию true
DEEPSEEK_API_KEY=sk-...  # обязателен
```

Иначе `Books::Import::Runner` сразу вызывает **legacy**-парсер для FB2/PDF.

Конфигурация ActiveHarness: `config/initializers/active_harness.rb`  
Модели: `deepseek-chat` (основная), `deepseek-reasoner` (fallback).

## Точка входа

```
Upload → ImportBookJob.perform(book_id)
      → Books::Import::Runner.call(book)
      → Books::Import::Orchestrator.call(book)   # mode: ai
```

`BookImport` создаётся со статусом `queued`, mode `ai`. UI опрашивает `/uploads/:uid/status` каждые 2 с.

## Фазы Orchestrator

### 1. Sampling (`FileSampler`)

- Читает файл из Active Storage.
- Собирает **окна текста** (начало, конец, середину, outline PDF).
- Метаданные: формат, число страниц, PDF outline.

Результат сохраняется в `book_import.sampler_artifacts`.

### 2. TOC Discovery (`TocDiscoveryAgent`)

- **Вход:** JSON с windows, metadata, page_count, format.
- **Выход:** JSON — найдено ли оглавление, `toc_entries[]` с title, page, level.
- До **3 раундов**: агент может запросить `action: inspect_windows` для дополнительных фрагментов.

Агент: `app/ai/agents/books/import/toc_discovery_agent.rb`  
Prompt: `app/ai/prompts/books/import/toc_discovery_prompt.rb`  
Формат ответа: **JSON** (`format :json`).

### 3. Structure Analysis (`StructureAnalysisAgent`)

- **Вход:** toc_discovery + sample_chapter + metadata.
- **Выход:** стратегия парсинга — `detected_format`, `chapter_detection_strategy`, `build_toc_while_parsing`, и т.д.

Сохраняется в `book_import.structure_analysis`.

### 4. Script loop (`generate_and_run!`)

До **`MAX_ITERATIONS = 10`** циклов:

| Шаг | status в UI | Действие |
|-----|-------------|----------|
| Генерация скрипта | `scripting` | `ParserScriptAuthorAgent` (итерация 0) или `ScriptFixAgent` (1+) |
| Статическая проверка | `validating` | `ScriptStaticValidator` — AST, запрещённые методы |
| Запуск | `running` | `ScriptRunner` — Docker sandbox или fallback ruby |
| Проверка JSON | `reviewing` | `OutputValidator` + JSON Schema |
| Качество | `reviewing` | `QualityReviewAgent` — hints для следующей итерации |

**Успех:** `validation_report.ok` → выход из цикла, `persist!`.  
**Провал 10 раз:** `LegacyImporter` (если формат поддержан).

#### Что получает агент на генерацию скрипта

**Первая итерация** (`ParserScriptAuthorAgent`):

```json
{
  "detected_format": "pdf",
  "toc_entries": [...],
  "output_rules": ["pages MUST be array of STRINGS..."],
  "canonical_snippet": "# пример Ruby для PDF",
  "reference_scripts": [
    { "source_format": "pdf", "script": "...", "page_count": 37 }
  ]
}
```

`reference_scripts` — до 2 последних **успешных** парсеров из таблицы `parser_script_samples` (тот же формат).

**Последующие итерации** (`ScriptFixAgent`):

```json
{
  "previous_script": "...",
  "validation_errors": ["..."],
  "validation_warnings": ["..."],
  "stderr": "...",
  "fix_hints": ["..."],
  "error_history": [{ "iteration": 2, "errors": [...], "unchanged": true }],
  "reference_scripts": [...]
}
```

Ответ LLM — **только Ruby-код** (без markdown). Orchestrator снимает обёртки ` ```ruby ` через `extract_ruby!`.

### 5. Запуск скрипта (`ScriptRunner`)

1. Пишет `parser.rb` и копию файла книги во временную директорию.
2. Запускает **изолированный контейнер**:

```bash
docker run --rm --network none --memory 512m --cpus 1 \
  -v .../parser.rb:/data/script/parser.rb:ro \
  -v .../book.pdf:/data/input/book.pdf:ro \
  dynamic-mcp-parser-sandbox:latest \
  /data/script/parser.rb /data/input/book.pdf
```

3. Ожидает JSON на stdout (до 50 MB, timeout 600 с).
4. Если Docker недоступен — fallback на `ruby` в процессе sidekiq (менее безопасно).

**Production:** задайте `BOOK_IMPORT_HOST_WORKDIR` на сервере — путь на хосте, соответствующий mount sidekiq (`./tmp/book-import` или абсолютный).

### 6. Валидация выхода

- `ScriptOutputNormalizer` — приводит pages/sections к контракту, убирает `reading_text: null`.
- `OutputValidator` — JSON Schema (`config/books/import_output_schema.json`).
- Несовпадение числа страниц PDF — **warning**, не блокер.

### 7. Persist

- `JsonMapper.to_parsed_document` → `ParsedDocument`
- `ParserScriptLibrary.record_success!` — сохраняет скрипт в `parser_script_samples` (только AI + успех)
- `Books::PersistParsedContent`
- `Search::Indexer.index_book!`
- `book.status = ready`

## ActiveHarness: как устроен агент

Агент — тонкий класс:

```ruby
class ParserScriptAuthorAgent < ActiveHarness::Agent
  include DeepseekAgent   # deepseek-chat + fallback reasoner
  system_prompt ParserScriptPrompt
end
```

Вызов:

```ruby
agent = ParserScriptAuthorAgent.call(input: JSON.pretty_generate(payload))
script = extract_ruby!(agent.result.output)
track_usage!(step, agent.result)  # tokens/cost в book_import_events
```

ActiveHarness собирает messages (system + user), вызывает DeepSeek API, возвращает `Result` с `output`, `parsed`, `usage`, `cost`.

## Безопасность скрипта

`ScriptStaticValidator` проверяет AST:

- разрешены `require`: `json`, `pdf-reader`, `nokogiri`, `rexml`;
- запрещены: `eval`, `system`, ``, network, `raise`, запись файлов, и т.д.

## Библиотека успешных скриптов

Таблица `parser_script_samples`:

| Поле | Описание |
|------|----------|
| source_format | pdf, fb2, … |
| script | текст Ruby |
| script_sha256 | уникальность в рамках формата |
| page_count, section_count | метаданные успешного прогона |

При новом импорте того же формата агент получает `reference_scripts` в контексте.

## Legacy fallback

После 10 неудачных итераций:

```ruby
LegacyImporter.call(@book)  # Fb2::Importer / Pdf::Importer
```

Использует `toc_entries` из AI discovery, если они есть. Mode импорта: `legacy_fallback`.

## UI прогресса

`Books::Import::Progress` отдаёт JSON:

- `phase`, `status`, `iteration`, `max_iterations`
- `script`, `script_iterations[]` — история с цветом ok/error/unchanged
- события из `book_import_events`

## Логи и отладка

```bash
docker-compose logs -f sidekiq    # ImportBookJob, скрипты
docker-compose logs -f web        # upload, status API
```

В Rails console на сервере:

```ruby
bi = Book.find_by(uid: "...").book_import
bi.events.order(:created_at).pluck(:step, :status, :message)
bi.generated_script
```

## Константы

| Константа | Значение | Файл |
|-----------|----------|------|
| MAX_ITERATIONS | 10 | `app/services/books/import.rb` |
| SCRIPT_TIMEOUT_SECONDS | 600 | там же |
| TOC_INSPECT_ROUNDS | 3 | там же |

## Связанные файлы

| Файл | Роль |
|------|------|
| `orchestrator.rb` | Главный pipeline |
| `parser_script_author_agent.rb` | Первая генерация |
| `script_fix_agent.rb` | Исправления |
| `script_runner.rb` | Docker sandbox |
| `script_static_validator.rb` | AST |
| `output_validator.rb` | JSON schema |
| `parser_script_library.rb` | reference_scripts |
| `canonical_script_template.rb` | PDF snippet |

Исторический план реализации: [AI_IMPORT_PLAN.md](AI_IMPORT_PLAN.md).

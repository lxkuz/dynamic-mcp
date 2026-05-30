module Books
  module Import
    class TocDiscoveryPrompt
      def call
        <<~PROMPT.strip
          You analyze book file samples to locate a table of contents (TOC).
          TOC may be long, at the start, middle, or end — or absent entirely.
          Reply ONLY with valid JSON (no markdown fences).

          ## When you need more text — ask for windows

          Example input: windows with ids "pdf-start-1-3", "pdf-p50-125-127"
          Example output:
          {"action":"inspect_windows","window_ids":["pdf-p50-125-127"],"reason":"Lines look like TOC entries with page numbers in the middle of the book"}

          ## When TOC is found

          Example output:
          {
            "action": "complete",
            "toc_found": true,
            "toc_location": {"page_from": 5, "page_to": 8},
            "toc_text": "Содержание\\nГлава 1 .......... 12\\nГлава 2 .......... 45",
            "toc_entries": [
              {"title": "Глава 1. Введение", "page": 12, "level": 1},
              {"title": "Глава 2. Основы", "page": 45, "level": 1},
              {"title": "2.1 Определения", "page": 48, "level": 2}
            ],
            "toc_truncated": false
          }

          ## When TOC is absent — NOT an error, continue parsing

          Example output:
          {
            "action": "complete",
            "toc_found": false,
            "toc_absent": true,
            "reason": "No TOC block found; chapters appear as headings on pages",
            "suggested_chapter_pattern": "^(Глава|Chapter)\\s+\\d+"
          }
        PROMPT
      end
    end
  end
end

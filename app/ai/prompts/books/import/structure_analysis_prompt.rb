module Books
  module Import
    class StructureAnalysisPrompt
      def call
        <<~PROMPT.strip
          You analyze book structure from TOC discovery + one sample chapter.
          Reply ONLY with valid JSON (no markdown fences).

          ## Example A — PDF with TOC

          {
            "detected_format": "pdf",
            "title": "Горные машины и оборудование карьеров",
            "author": "Иванов И.И.",
            "toc_found": true,
            "has_structured_toc": true,
            "pagination_mode": "physical",
            "toc_entries": [
              {"title": "Глава 1", "page": 12, "level": 1},
              {"title": "Глава 2", "page": 45, "level": 1}
            ],
            "chapter_detection_strategy": "from_toc",
            "build_toc_while_parsing": false,
            "sample_chapter": {"page_from": 12, "page_to": 14, "title": "Глава 1"},
            "parser_notes": "Use pdf-reader; sections from toc_entries page ranges",
            "suggested_gems": ["pdf-reader", "json"],
            "confidence": 0.9
          }

          ## Example B — PDF without TOC (build sections while parsing)

          {
            "detected_format": "pdf",
            "title": "Технический отчёт",
            "author": "",
            "toc_found": false,
            "has_structured_toc": false,
            "pagination_mode": "physical",
            "toc_entries": [],
            "chapter_detection_strategy": "inline_headings",
            "build_toc_while_parsing": true,
            "sample_chapter": {"page_from": 1, "page_to": 2, "title": "sample"},
            "parser_notes": "Scan pages for headings like 'Глава N'; build sections on the fly",
            "suggested_gems": ["pdf-reader", "json"],
            "confidence": 0.75
          }

          ## Example C — FB2

          {
            "detected_format": "fb2",
            "title": "Тестовая книга",
            "author": "Автор",
            "toc_found": true,
            "has_structured_toc": true,
            "pagination_mode": "virtual",
            "toc_entries": [],
            "chapter_detection_strategy": "heuristic",
            "build_toc_while_parsing": false,
            "sample_chapter": {"page_from": null, "page_to": null, "title": "Глава 1"},
            "parser_notes": "Parse XML sections with nokogiri; split body into virtual pages ~1800 chars",
            "suggested_gems": ["nokogiri", "json"],
            "confidence": 0.85
          }

          ## Example D — EPUB

          {
            "detected_format": "epub",
            "title": "Sample EPUB",
            "author": "Author",
            "toc_found": false,
            "has_structured_toc": false,
            "pagination_mode": "virtual",
            "toc_entries": [],
            "chapter_detection_strategy": "spine",
            "build_toc_while_parsing": true,
            "sample_chapter": {"page_from": null, "page_to": null, "title": "Chapter 1"},
            "parser_notes": "EPUB is ZIP: require zip + nokogiri; open with Zip::File; read OPF spine XHTML; virtual pages ~1800 chars",
            "suggested_gems": ["zip", "nokogiri", "json"],
            "confidence": 0.85
          }
        PROMPT
      end
    end
  end
end

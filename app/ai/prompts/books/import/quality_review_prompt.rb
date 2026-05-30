module Books
  module Import
    class QualityReviewPrompt
      def call
        <<~PROMPT.strip
          Review parser output quality. You see stats and short samples only — not the full book.
          Reply ONLY with JSON (no markdown fences).

          ## Example — good output

          Input stats: {"page_count": 320, "avg_chars_per_page": 1800, "section_count": 12}
          Output:
          {"ok": true, "issues": [], "fix_hints": ""}

          ## Example — truncated pages (bad)

          Input stats: {"page_count": 320, "avg_chars_per_page": 180, "section_count": 5}
          sample_pages: ["Глава 1. Введение в горное дело и основные понятия...", "..."]
          Output:
          {
            "ok": false,
            "issues": ["pages contain previews (~200 chars) not full text", "avg_chars_per_page too low for PDF"],
            "fix_hints": "Change pages to full reader.page(n).text strings for all pages; remove content_preview objects"
          }

          ## Example — empty title

          Output:
          {"ok": false, "issues": ["title is blank"], "fix_hints": "Extract title from PDF info or first page heading"}
        PROMPT
      end
    end
  end
end

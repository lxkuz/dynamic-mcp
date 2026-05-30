module Books
  module Import
    class ContextFormatter
      MAX_TOC_DISCOVERY_CHARS = 24_000
      MAX_TOC_CHARS = 12_000
      MAX_CHAPTER_CHARS = 6_000

      class << self
        def windows_payload(windows, ids: nil)
          selected = ids ? windows.select { |w| ids.include?(w[:window_id]) } : windows
          selected.map do |window|
            {
              window_id: window[:window_id],
              page_from: window[:page_from],
              page_to: window[:page_to],
              label: window[:label],
              text: truncate(window[:text], MAX_TOC_DISCOVERY_CHARS / [ selected.size, 1 ].max)
            }
          end
        end

        def toc_text(text)
          truncate(text, MAX_TOC_CHARS)
        end

        def chapter_text(text)
          truncate(text, MAX_CHAPTER_CHARS)
        end

        def truncate(text, limit)
          str = text.to_s
          return str if str.length <= limit

          half = limit / 2
          "#{str[0, half]}\n…\n#{str[-half, half]}"
        end
      end
    end
  end
end

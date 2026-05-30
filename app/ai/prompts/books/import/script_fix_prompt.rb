module Books
  module Import
    class ScriptFixPrompt
      def call
        <<~PROMPT.strip
          Fix the Ruby book parser script using validation_errors, stderr, output_rules,
          previous_script, fix_hints, error_history, and quality_issues.

          Input JSON fields:
          - validation_errors, validation_warnings — from last run
          - fix_hints, quality_issues — from quality review
          - error_history — same errors on prior iterations; if unchanged:true, you MUST change approach
          - reference_scripts — working parsers for this format; adapt them
          - iteration — current attempt number

          IMPORTANT: Do NOT output reading_text: null — omit reading_text entirely when using pages array.

          ## Common mistake to fix

          WRONG:
          pages << {"page_number" => idx + 1, "content_preview" => text[0..200]}

          CORRECT:
          pages = (1..reader.page_count).map { |n| reader.page(n).text.to_s.delete("\\u0000") }

          ## Example fix context

          validation_errors: ["The property '#/' of type object did not match items of type string in pages"]
          fix_hints: "pages must be array of strings with full page text"

          Your script must output:
          puts JSON.generate("title" => ..., "author" => ..., "pages" => [...strings...], "sections" => [...])

          Allowed requires: json, pdf-reader, nokogiri, rexml only. No raise, no shell.

          Reply ONLY with the complete fixed Ruby script (no markdown fences).
        PROMPT
      end
    end
  end
end

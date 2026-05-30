module Books
  module Import
    class Orchestrator
      def self.call(book)
        new(book).call
      end

      def initialize(book)
        @book = book
        @import = book.book_import || book.create_book_import!(status: "queued", mode: "ai")
      end

      def call
        @import.update!(status: "sampling", started_at: Time.current, error_message: nil)
        @book.update!(status: "processing", error_message: nil)

        artifacts = sample_file!
        toc = discover_toc!(artifacts)
        structure = analyze_structure!(artifacts, toc)
        result = generate_and_run!(structure, artifacts)

        if result == :legacy
          @import.succeed!
          @book.reload
          return
        end

        persist!(result)
        @import.succeed!
        @book.reload
      rescue StandardError => e
        Rails.logger.error("[ImportOrchestrator] book=#{@book.id} #{e.class}: #{e.message}\n#{e.backtrace.first(5).join("\n")}")
        @import&.fail!(e.message)
        raise
      end

      private

      def sample_file!
        @import.update!(status: "sampling")
        artifacts = nil
        @book.source_file.open { |io| artifacts = FileSampler.call(@book, io: io) }
        @import.update!(sampler_artifacts: artifacts)
        @import.log_event!(step: "sample_file", status: "ok", payload: { window_count: artifacts[:windows].size })
        artifacts
      end

      def discover_toc!(artifacts)
        @import.update!(status: "discovering_toc")
        windows = artifacts[:windows]
        payload = {
          format: artifacts[:format],
          page_count: artifacts[:page_count],
          outline: artifacts[:outline],
          metadata: artifacts[:metadata],
          windows: ContextFormatter.windows_payload(windows)
        }

        result = nil
        Import::TOC_INSPECT_ROUNDS.times do |round|
          agent = TocDiscoveryAgent.call(input: JSON.pretty_generate(payload))
          track_usage!("toc_discovery_#{round}", agent.result)

          parsed = agent.result.parsed || {}
          if parsed["action"] == "inspect_windows"
            ids = parsed["window_ids"] || []
            payload[:windows] = ContextFormatter.windows_payload(windows, ids: ids)
            next
          end

          result = parsed
          break
        end

        result ||= { "toc_found" => false, "toc_absent" => true, "reason" => "TOC discovery exhausted rounds" }
        @import.update!(toc_discovery: result)
        @import.log_event!(step: "discover_toc", status: "ok", payload: { toc_found: result["toc_found"] })
        result
      end

      def analyze_structure!(artifacts, toc)
        @import.update!(status: "analyzing")
        sample_chapter = sample_chapter_text(artifacts, toc)

        input = {
          toc_discovery: toc,
          metadata: artifacts[:metadata],
          format: artifacts[:format],
          page_count: artifacts[:page_count],
          sample_chapter: sample_chapter
        }

        agent = StructureAnalysisAgent.call(input: JSON.pretty_generate(input))
        track_usage!("structure_analysis", agent.result)

        structure = agent.result.parsed || {}
        @import.update!(structure_analysis: structure)
        @import.log_event!(step: "analyze_structure", status: "ok")
        structure
      end

      def generate_and_run!(structure, artifacts)
        script = nil
        last_result = nil

        Import::MAX_ITERATIONS.times do |iteration|
          @import.update!(
            iteration: iteration + 1,
            status: "scripting",
            validation_report: nil,
            last_run_stderr: nil,
            quality_report: nil
          )
          script = author_script!(structure, script, last_result, iteration)
          @import.update!(generated_script: script, script_sha256: Digest::SHA256.hexdigest(script))
          Rails.logger.info("[book_import book=#{@book.id} iteration=#{iteration + 1}] generated script:\n#{script}")

          @import.update!(status: "validating")
          validation = ScriptStaticValidator.call(script)
          unless validation.safe
            message = validation.violations.join(", ")
            @import.log_event!(step: "validate_script", status: "error", message: message)
            log_script_iteration!(script, outcome: "error", errors: validation.violations)
            last_result = { stderr: message, validation: validation }
            next
          end

          @import.update!(status: "running")
          run_result = run_script!(script)
          @import.update!(
            last_run_stdout: run_result.stdout&.truncate(20_000),
            last_run_stderr: run_result.stderr&.truncate(20_000)
          )

          unless run_result.json
            @import.log_event!(
              step: "run_script",
              status: "error",
              message: run_result.stderr.presence || "invalid JSON stdout"
            )
            log_script_iteration!(
              script,
              outcome: "error",
              errors: [ run_result.stderr.presence || "invalid JSON stdout" ]
            )
            last_result = failure_context_from_run(run_result)
            next
          end

          normalized = ScriptOutputNormalizer.call(run_result.json)
          @import.update!(status: "reviewing")
          validation_report = OutputValidator.call(
            normalized,
            expected_page_count: artifacts[:page_count]
          )
          @import.update!(validation_report: validation_report.to_h)

          if validation_report.ok
            @import.log_event!(step: "validate_output", status: "ok")
            log_script_iteration!(script, outcome: "ok")
            return normalized
          end

          quality = review_quality!(structure, validation_report, normalized)
          @import.update!(quality_report: quality)
          log_script_iteration!(script, outcome: "error", errors: validation_report.errors)

          last_result = {
            stderr: run_result.stderr,
            validation: validation_report,
            quality: quality,
            normalized_sample: normalized["pages"]&.first.to_s.truncate(200)
          }
        end

        return :legacy if try_legacy_fallback!

        raise "Import failed after #{Import::MAX_ITERATIONS} iterations"
      end

      def try_legacy_fallback!
        return false unless LegacyImporter.supported?(@book.source_format)

        @import.log_event!(step: "legacy_fallback", status: "started", message: "AI iterations exhausted")
        LegacyImporter.call(@book)
        @import.log_event!(step: "legacy_fallback", status: "ok")
        true
      end

      def log_script_iteration!(script, outcome:, errors: [])
        sha = Digest::SHA256.hexdigest(script.to_s)
        prev_sha = @import.events.where(step: "script_iteration").order(:created_at).last&.payload&.dig("sha256")
        @import.log_event!(
          step: "script_iteration",
          status: outcome,
          iteration: @import.iteration,
          message: errors.first,
          payload: {
            script: script.to_s.truncate(12_000),
            errors: errors.map(&:to_s).reject(&:blank?).first(8),
            sha256: sha,
            unchanged: prev_sha.present? && prev_sha == sha
          }
        )
      end

      def error_history_for_fix
        @import.events.where(step: "script_iteration", status: "error").order(:iteration).last(5).filter_map do |event|
          errors = Array(event.payload&.dig("errors")).reject(&:blank?)
          next if errors.empty?

          {
            iteration: event.iteration,
            errors: errors,
            unchanged: event.payload&.dig("unchanged") == true
          }
        end
      end

      def author_script!(structure, previous_script, last_result, iteration)
        format = structure["detected_format"] || @book.source_format
        references = ParserScriptLibrary.references_for(format)

        if iteration.zero? || previous_script.blank?
          payload = structure.merge(
            "output_rules" => output_rules_for(structure),
            "canonical_snippet" => canonical_snippet_for(structure),
            "reference_scripts" => references
          )
          agent = ParserScriptAuthorAgent.call(input: JSON.pretty_generate(payload))
          track_usage!("parser_script_author_#{iteration}", agent.result)
          extract_ruby!(agent.result.output)
        else
          ctx = last_result.is_a?(Hash) ? last_result : {}
          validation = ctx[:validation] || ctx["validation"]
          quality = ctx[:quality] || ctx["quality"] || {}
          fix_input = {
            structure: structure,
            output_rules: output_rules_for(structure),
            previous_script: previous_script,
            reference_scripts: references,
            iteration: iteration + 1,
            stderr: ctx[:stderr] || ctx["stderr"],
            validation_errors: validation_messages(validation),
            validation_warnings: validation_warnings(validation),
            fix_hints: quality["fix_hints"].presence || quality[:fix_hints],
            quality_issues: quality["issues"] || quality[:issues],
            normalized_sample: ctx[:normalized_sample] || ctx["normalized_sample"],
            error_history: error_history_for_fix
          }
          agent = ScriptFixAgent.call(input: JSON.pretty_generate(fix_input))
          track_usage!("script_fix_#{iteration}", agent.result)
          extract_ruby!(agent.result.output)
        end
      end

      def validation_messages(validation)
        return validation.errors if validation.respond_to?(:errors)
        return validation.violations if validation.respond_to?(:violations)

        nil
      end

      def validation_warnings(validation)
        return validation.warnings if validation.respond_to?(:warnings)

        []
      end

      def failure_context_from_run(run_result)
        {
          stderr: run_result.stderr.presence || "invalid JSON stdout",
          stdout: run_result.stdout&.truncate(2000),
          exit_code: run_result.exit_code,
          validation: nil,
          quality: nil,
          normalized_sample: nil
        }
      end

      def output_rules_for(structure)
        format = (structure["detected_format"] || @book.source_format).to_s
        rules = [
          "pages MUST be a JSON array of STRINGS — full text of each page, NOT objects",
          "Do NOT use content_preview or {page_number: ...} objects in pages",
          "sections may be empty array if unknown",
          "Use puts JSON.generate(...) not pretty_generate"
        ]
        if format == "fb2"
          rules.concat([
            "FB2: require nokogiri — load with Nokogiri::XML(File.read(ARGV[0])); doc.remove_namespaces!",
            "Do NOT use pdf-reader for FB2",
            "Split book text into virtual pages (~1800 chars) or provide reading_text string",
            "Build sections from //body/section with title, plain_text, depth, children",
            "page_start/page_end optional for FB2 (omit or null)"
          ])
        end
        rules
      end

      def canonical_snippet_for(structure)
        format = structure["detected_format"] || @book.source_format
        return CanonicalScriptTemplate.pdf_snippet if format.to_s == "pdf"
        return CanonicalScriptTemplate.fb2_snippet if format.to_s == "fb2"

        nil
      end

      def run_script!(script)
        @book.source_file.open do |io|
          Tempfile.create([ "book-source", ".#{@book.source_format}" ]) do |tmp|
            tmp.binmode
            tmp.write(io.read)
            tmp.flush
            ScriptRunner.call(
              script_source: script,
              source_path: tmp.path,
              source_format: @book.source_format,
              book_import: @import
            )
          end
        end
      end

      def review_quality!(structure, validation_report, json)
        pages = json["pages"] || []
        input = {
          structure: structure,
          stats: validation_report.stats,
          warnings: validation_report.warnings,
          errors: validation_report.errors,
          sample_pages: pages.first(2).map { |text| ContextFormatter.chapter_text(text.to_s) }
        }
        agent = QualityReviewAgent.call(input: JSON.pretty_generate(input))
        track_usage!("quality_review", agent.result)
        agent.result.parsed || { "ok" => validation_report.ok, "issues" => validation_report.errors }
      end

      def persist!(json)
        @import.update!(status: "persisting")
        parsed = JsonMapper.to_parsed_document(json)
        record_parser_script_sample!(parsed)
        Books::PersistParsedContent.call(@book, parsed)

        @import.update!(status: "indexing")
        Search::Indexer.index_book!(@book)
        @book.update!(status: "ready")
        @import.log_event!(step: "persist", status: "ok")
      end

      def sample_chapter_text(artifacts, toc)
        if toc["toc_entries"].is_a?(Array) && toc["toc_entries"].any?
          entry = toc["toc_entries"].first
          page = entry["page"]
          if page && artifacts[:format].to_s == "pdf"
            return extract_pdf_pages(artifacts, page, page + 2, entry["title"])
          end
        end

        window = artifacts[:windows].find { |w| w[:label] == "start" } || artifacts[:windows].first
        {
          title: "sample",
          page_from: window&.dig(:page_from),
          page_to: window&.dig(:page_to),
          text: ContextFormatter.chapter_text(window&.dig(:text).to_s)
        }
      end

      def extract_pdf_pages(artifacts, from_page, to_page, title)
        texts = []
        @book.source_file.open do |io|
          reader = PDF::Reader.new(io)
          (from_page..to_page).each do |n|
            next if n > reader.page_count

            texts << reader.page(n).text.to_s
          end
        end
        {
          title: title,
          page_from: from_page,
          page_to: to_page,
          text: ContextFormatter.chapter_text(texts.join("\n\n"))
        }
      end

      def extract_ruby!(output)
        text = output.to_s.strip
        text = text.sub(/\A```ruby\n?/i, "").sub(/\A```\n?/, "").sub(/\n?```\z/, "")
        text.strip
      end

      def record_parser_script_sample!(parsed)
        return if @import.mode != "ai"
        return if @import.generated_script.blank?

        ParserScriptLibrary.record_success!(
          book: @book,
          book_import: @import,
          script: @import.generated_script,
          stats: {
            page_count: parsed.pages&.size || @book.page_count,
            section_count: count_sections(parsed.sections)
          }
        )
      rescue StandardError => e
        Rails.logger.warn("[ParserScriptLibrary] book=#{@book.id} failed to save sample: #{e.message}")
      end

      def count_sections(nodes)
        Array(nodes).sum do |node|
          children = node.respond_to?(:children) ? node.children : node[:children]
          1 + count_sections(children)
        end
      end

      def track_usage!(step, result)
        return unless result.respond_to?(:usage)

        @import.record_llm_usage!(step, result.usage)
      end
    end
  end
end

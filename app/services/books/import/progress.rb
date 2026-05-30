module Books
  module Import
    module Progress
      PHASES = [
        { key: "queued", label: "В очереди", hint: "Ожидание Sidekiq" },
        { key: "sampling", label: "Анализ файла", hint: "Чтение образцов страниц" },
        { key: "discovering_toc", label: "Поиск оглавления", hint: "AI ищет TOC в документе" },
        { key: "analyzing", label: "Структура книги", hint: "Определение глав и формата" }
      ].freeze

      LOOP_PHASES = [
        { key: "scripting", label: "Генерация скрипта", hint: "AI пишет Ruby-парсер" },
        { key: "validating", label: "Проверка кода", hint: "Статический анализ скрипта" },
        { key: "running", label: "Запуск парсера", hint: "Sandbox выполняет скрипт" },
        { key: "reviewing", label: "Оценка результата", hint: "Проверка JSON и качества" }
      ].freeze

      FINAL_PHASES = [
        { key: "legacy_fallback", label: "Legacy-импорт", hint: "AI не справился — встроенный PDF/FB2 парсер" },
        { key: "persisting", label: "Сохранение", hint: "Запись в базу данных" },
        { key: "indexing", label: "Индексация", hint: "Elasticsearch" },
        { key: "ready", label: "Готово", hint: "Книга доступна" }
      ].freeze

      STATUS_ORDER = (PHASES + LOOP_PHASES + FINAL_PHASES).map { |p| p[:key] }.freeze

      EVENT_LABELS = {
        "sample_file" => "Файл проанализирован",
        "discover_toc" => "Оглавление",
        "analyze_structure" => "Структура определена",
        "validate_script" => "Проверка скрипта",
        "run_script" => "Запуск парсера",
        "validate_output" => "Валидация результата",
        "script_iteration" => "Версия скрипта",
        "legacy_fallback" => "Legacy-импорт",
        "legacy_import" => "Legacy-импорт",
        "persist" => "Сохранение завершено"
      }.freeze

      module_function

      def phase_index(status)
        idx = STATUS_ORDER.index(status.to_s)
        idx.nil? ? -1 : idx
      end

      def payload_for(import)
        return nil unless import

        {
          status: import.status,
          mode: import.mode,
          iteration: import.iteration,
          max_iterations: Import::MAX_ITERATIONS,
          error_message: import.error_message,
          started_at: import.started_at,
          finished_at: import.finished_at,
          phases: PHASES,
          loop_phases: LOOP_PHASES,
          final_phases: FINAL_PHASES,
          recent_events: import.events.order(created_at: :desc).limit(12).reject { |e| e.step == "script_iteration" }.map { |event| event_payload(event) },
          script: script_preview_for(import),
          script_iterations: script_iterations_for(import)
        }
      end

      def script_preview_for(import)
        return nil if import.generated_script.blank?

        {
          iteration: import.iteration,
          sha256: import.script_sha256,
          state: script_state(import),
          script: import.generated_script.to_s.truncate(12_000),
          errors: current_script_errors(import)
        }
      end

      def script_iterations_for(import)
        import.events.where(step: "script_iteration").order(:iteration, :created_at).filter_map do |event|
          script = event.payload&.dig("script").to_s
          next if script.blank?

          {
            id: event.id,
            iteration: event.iteration,
            state: event.status,
            script: script,
            errors: Array(event.payload&.dig("errors")),
            message: event.message,
            sha256: event.payload&.dig("sha256"),
            unchanged: event.payload&.dig("unchanged") == true,
            created_at: event.created_at
          }
        end
      end

      def script_state(import)
        case import.status
        when "scripting" then "writing"
        when "validating" then "validating"
        when "running" then "running"
        when "reviewing"
          report = import.validation_report
          report.is_a?(Hash) && report["ok"] ? "ok" : "error"
        when "persisting", "indexing", "ready" then "ok"
        else "pending"
        end
      end

      def current_script_errors(import)
        if import.status == "reviewing"
          report = import.validation_report
          if report.is_a?(Hash) && report["errors"].present?
            return Array(report["errors"]).map(&:to_s).reject(&:blank?).uniq.first(6)
          end
        end

        errors = iteration_errors(import, import.iteration)
        return errors if errors.any?

        return [] if in_progress_iteration?(import)

        report = import.validation_report
        Array(report["errors"]).map(&:to_s).reject(&:blank?).uniq.first(6)
      end

      def in_progress_iteration?(import)
        import.status.in?(%w[scripting validating running])
      end

      def iteration_errors(import, iteration)
        errors = []
        import.events.where(step: "script_iteration", iteration: iteration, status: "error").order(:created_at).each do |event|
          errors.concat(Array(event.payload&.dig("errors")))
          errors << event.message if event.message.present?
        end

        if errors.empty?
          import.events.where(step: %w[validate_script run_script], iteration: iteration, status: "error").order(:created_at).each do |event|
            errors << event.message if event.message.present?
          end
        end

        errors.map(&:to_s).reject(&:blank?).uniq.first(6)
      end

      def event_payload(event)
        {
          id: event.id,
          step: event.step,
          label: EVENT_LABELS[event.step] || event.step,
          status: event.status,
          message: event.message,
          iteration: event.iteration,
          created_at: event.created_at
        }
      end
    end
  end
end

require "timeout"

module Books
  module Import
    class ScriptRunner
      Result = Data.define(:success, :stdout, :stderr, :exit_code, :json, :duration_seconds) do
        def success? = success
      end

      MAX_STDOUT_BYTES = 50.megabytes
      WORK_ROOT = ENV.fetch("BOOK_IMPORT_WORKDIR", Rails.root.join("tmp", "book-import").to_s).freeze
      HOST_WORK_ROOT = ENV.fetch("BOOK_IMPORT_HOST_WORKDIR", WORK_ROOT).freeze
      # Match Docker infrastructure failures only — not Ruby Errno::EACCES inside the sandbox.
      DOCKER_ERROR_PATTERN = /cannot connect to the Docker daemon|docker not available|permission denied while trying to connect to the Docker daemon/i

      def self.call(script_source:, source_path:, source_format:, book_import:)
        new(script_source, source_path, source_format, book_import).call
      end

      def initialize(script_source, source_path, source_format, book_import)
        @script_source = script_source
        @source_path = source_path
        @source_format = source_format
        @book_import = book_import
      end

      def call
        FileUtils.mkdir_p(WORK_ROOT)
        Dir.mktmpdir("run-", WORK_ROOT) do |workdir|
          script_path = File.join(workdir, "parser.rb")
          input_name = "book.#{@source_format}"
          input_path = File.join(workdir, input_name)

          File.write(script_path, @script_source)
          FileUtils.cp(@source_path, input_path)
          # Sandbox runs as nobody — ActiveStorage blobs are often 0600.
          File.chmod(0o644, script_path, input_path)

          result = run_docker(script_path, input_path)
          if result.success? || !docker_fallback?(result)
            result
          else
            @book_import.log_event!(
              step: "run_script",
              status: "warn",
              message: "docker unavailable, running parser locally"
            )
            run_local(script_path, input_path)
          end
        end
      end

      private

      def run_docker(script_path, input_path)
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        stdout, stderr, status = Timeout.timeout(Import::SCRIPT_TIMEOUT_SECONDS) do
          Open3.capture3(*docker_command(script_path, input_path))
        end
        build_result(stdout, stderr, status, started)
      rescue Timeout::Error
        timeout_result
      rescue Errno::ENOENT => e
        Result.new(
          success: false,
          stdout: "",
          stderr: "docker not available: #{e.message}",
          exit_code: 127,
          json: nil,
          duration_seconds: 0
        )
      end

      def run_local(script_path, input_path)
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        stdout, stderr, status = Timeout.timeout(Import::SCRIPT_TIMEOUT_SECONDS) do
          Open3.capture3("ruby", script_path, input_path)
        end
        build_result(stdout, stderr, status, started)
      rescue Timeout::Error
        timeout_result
      end

      def build_result(stdout, stderr, status, started)
        duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
        stdout = stdout.byteslice(0, MAX_STDOUT_BYTES)
        @book_import.log_event!(
          step: "run_script",
          status: status.success? ? "ok" : "error",
          message: "exit=#{status.exitstatus} duration=#{duration.round(2)}s",
          payload: { stderr: stderr.truncate(4000) }
        )

        json = parse_json(stdout) if status.success?
        Result.new(
          success: status.success? && json.present?,
          stdout: stdout,
          stderr: stderr,
          exit_code: status.exitstatus,
          json: json,
          duration_seconds: duration
        )
      end

      def timeout_result
        Result.new(
          success: false,
          stdout: "",
          stderr: "timeout after #{Import::SCRIPT_TIMEOUT_SECONDS}s",
          exit_code: 124,
          json: nil,
          duration_seconds: Import::SCRIPT_TIMEOUT_SECONDS
        )
      end

      def docker_fallback?(result)
        result.stderr.to_s.match?(DOCKER_ERROR_PATTERN)
      end

      def docker_command(script_path, input_path)
        [
          "docker", "run", "--rm",
          "--network", "none",
          "--memory", "512m",
          "--cpus", "1",
          "-v", "#{host_path(script_path)}:/data/script/parser.rb:ro",
          "-v", "#{host_path(input_path)}:/data/input/book.#{@source_format}:ro",
          Import::PARSER_SANDBOX_IMAGE,
          "/data/script/parser.rb", "/data/input/book.#{@source_format}"
        ]
      end

      def host_path(path)
        path = path.to_s
        return path if HOST_WORK_ROOT == WORK_ROOT
        return path unless path.start_with?(WORK_ROOT)

        relative = path.delete_prefix(WORK_ROOT).delete_prefix("/")
        File.join(HOST_WORK_ROOT, relative)
      end

      def parse_json(stdout)
        JSON.parse(stdout)
      rescue JSON::ParserError
        nil
      end
    end
  end
end

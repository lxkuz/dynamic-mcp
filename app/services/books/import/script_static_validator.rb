require "parser/current"

module Books
  module Import
    class ScriptStaticValidator
      FORBIDDEN_SENDS = %w[
        eval system exec spawn exit abort fork kill sleep
        load autoload autoload?
        ` %x open_popen
      ].freeze

      ALLOWED_REQUIRES = %w[json pdf-reader nokogiri rexml].freeze

      FORBIDDEN_CONST = %w[
        FileUtils Dir IO Process Open3 Net::HTTP Net::HTTPS Socket TCPSocket
        Kernel Binding ENV
      ].freeze

      ALLOWED_FILE_METHODS = %w[read].freeze

      Result = Data.define(:safe, :violations) do
        def errors = violations
        def warnings = []
      end

      def self.call(source)
        new(source).call
      end

      def initialize(source)
        @source = source.to_s
      end

      def call
        violations = []
        violations.concat(regex_violations)
        violations.concat(ast_violations)
        Result.new(safe: violations.empty?, violations: violations.uniq)
      end

      private

      def regex_violations
        list = []
        list << "backticks forbidden" if @source.match?(/`[^`]*`/)
        list << "%x forbidden" if @source.include?("%x{") || @source.include?("%x(")
        list << "eval forbidden" if @source.match?(/\beval\s*\(/)
        list << "require outside allowlist" if @source.match?(/\brequire(?:_relative)?\s+['"](?!json|pdf-reader|nokogiri|rexml)/)
        list
      end

      def ast_violations
        buffer = ::Parser::CurrentRuby.parse(@source)
        return [ "syntax error: unable to parse Ruby" ] if buffer.nil?

        visitor = ForbiddenVisitor.new
        visitor.process(buffer)
        visitor.violations
      rescue ::Parser::SyntaxError => e
        [ "syntax error: #{e.message}" ]
      end

      class ForbiddenVisitor < ::Parser::AST::Processor
        attr_reader :violations

        def initialize
          @violations = []
        end

        def on_xstr(node)
          @violations << "backticks forbidden"
          super
        end

        def on_send(node)
          receiver = node.children[0]
          method = node.children[1].to_s

          if file_receiver?(receiver)
            unless ALLOWED_FILE_METHODS.include?(method)
              @violations << "forbidden File method: #{method}"
            end
          end

          case method
          when "require"
            arg = string_argument(node.children[2])
            @violations << "require outside allowlist: #{arg || '?'}" unless ALLOWED_REQUIRES.include?(arg)
          when "require_relative"
            @violations << "require_relative forbidden"
          when *FORBIDDEN_SENDS
            @violations << "forbidden method: #{method}"
          end
          super
        end

        def file_receiver?(node)
          return false unless node

          node.type == :const && const_name(node) == "File"
        end

        def string_argument(node)
          return unless node&.type == :str

          node.children[0].to_s
        end

        def on_const(node)
          name = const_name(node)
          @violations << "forbidden constant: #{name}" if FORBIDDEN_CONST.include?(name)
          super
        end

        def const_name(node)
          parts = []
          current = node
          while current&.type == :const
            parts.unshift(current.children.last)
            current = current.children.first
          end
          parts.join("::")
        end
      end
    end
  end
end

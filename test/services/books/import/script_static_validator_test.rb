require "test_helper"

module Books
  module Import
    class ScriptStaticValidatorTest < ActiveSupport::TestCase
      test "allows zip and zlib requires for EPUB parsers" do
        source = <<~RUBY
          require "json"
          require "zip"
          require "zlib"
          require "nokogiri"

          Zip::File.open(ARGV[0]) do |zip|
            puts JSON.generate("title" => "", "author" => "", "pages" => ["ok"], "sections" => [])
          end
        RUBY

        result = ScriptStaticValidator.call(source)
        assert result.safe, result.violations.inspect
      end

      test "rejects unknown requires" do
        source = <<~RUBY
          require "json"
          require "open3"
        RUBY

        result = ScriptStaticValidator.call(source)
        assert_not result.safe
        assert result.violations.any? { |v| v.include?("require outside allowlist") }
      end

      test "still rejects File.binread" do
        source = <<~RUBY
          require "json"
          data = File.binread(ARGV[0])
          puts JSON.generate("title" => "", "author" => "", "pages" => [data], "sections" => [])
        RUBY

        result = ScriptStaticValidator.call(source)
        assert_not result.safe
        assert_includes result.violations, "forbidden File method: binread"
      end

      test "epub canonical snippet is statically safe" do
        # Wrap snippet as a complete script with json require for AST completeness.
        source = <<~RUBY
          require "json"
          #{CanonicalScriptTemplate.epub_snippet}
          puts JSON.generate("title" => title, "author" => author, "pages" => pages, "sections" => [])
        RUBY

        result = ScriptStaticValidator.call(source)
        assert result.safe, result.violations.inspect
      end

      test "ALLOWED_REQUIRES includes zip and zlib" do
        assert_includes ScriptStaticValidator::ALLOWED_REQUIRES, "zip"
        assert_includes ScriptStaticValidator::ALLOWED_REQUIRES, "zlib"
      end
    end
  end
end

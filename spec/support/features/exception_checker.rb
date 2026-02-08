module Features
  module ExceptionChecker
    # Track log file position at start of test
    def initialize_log_position
      log_file = Rails.root.join('log/test.log')
      @log_start_position = log_file.exist? ? File.size(log_file) : 0
    end

    # Check test.log for any ERROR/FATAL messages since test started
    def assert_no_log_errors(context = '')
      log_content = recent_log_content
      return if log_content.nil? || log_content.empty?

      error_patterns = [/ERROR|FATAL/]
      error_patterns.each do |pattern|
        next unless log_content.match?(pattern)

        context_msg = context.empty? ? '' : " (#{context})"
        error_snippet = log_snippet(log_content, pattern)
        raise "ERROR IN LOGS#{context_msg}:\n#{error_snippet}"
      end
    end

    def recent_log_content
      log_file = Rails.root.join('log/test.log')
      return nil unless log_file.exist?

      current_size = File.size(log_file)
      return nil if current_size <= @log_start_position

      File.read(log_file, current_size - @log_start_position, @log_start_position)
    end

    def log_snippet(log_content, pattern)
      log_content[/.*#{pattern}.*?\n.{0,500}/m]
    end

    # Also check page body as fallback
    def assert_no_page_exceptions(context = '')
      exception_patterns = [
        /undefined method/i,
        /NoMethodError/i,
        /Puma caught this error/i,
        /ActionView::Template::Error/i,
        /nil:NilClass/
      ]

      exception_patterns.each do |pattern|
        if page.body.match?(pattern)
          context_msg = context.empty? ? '' : " (#{context})"
          raise "EXCEPTION IN PAGE#{context_msg}:\n#{page.body[/.*#{pattern}.{0,200}/m]}"
        end
      end
    end
  end
end

RSpec.configure do |c|
  c.include Features::ExceptionChecker, type: :feature
  c.include Features::ExceptionChecker, type: :controller
  c.include Features::ExceptionChecker, type: :request
  c.include Features::ExceptionChecker, type: :view
  c.include Features::ExceptionChecker, type: :model
  c.include Features::ExceptionChecker, type: :service

  # Initialize log position before each test (only for specs that have the method)
  c.before(:each) do
    initialize_log_position if respond_to?(:initialize_log_position)
  end

  # Check after each test (skip if already failing)
  c.after(:each) do |example|
    next unless example.exception.nil?

    next unless respond_to?(:assert_no_log_errors)

    if example.metadata[:expect_log_error]
      begin
        assert_no_log_errors("after #{example.description}")
        raise "Expected log errors but found none (#{example.description})"
      rescue RuntimeError
        # Expected: log errors were detected.
      end
    else
      assert_no_log_errors("after #{example.description}")
    end
  end
end

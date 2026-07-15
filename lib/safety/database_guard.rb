# frozen_string_literal: true

module Safety
  class DatabaseGuard
    DANGEROUS_DB_TASK_PREFIXES = %w[
      db:drop
      db:purge
      db:reset
      db:schema:load
      db:structure:load
      db:test:prepare
      db:fixtures:load
      db:truncate_all
    ].freeze

    def self.abort_if_dangerous_db_task!(argv: ARGV, env: ENV, output: $stderr)
      tasks = Array(argv).grep(/\Adb:/)
      return if tasks.empty?
      return unless tasks.any? { |task| dangerous_db_task?(task) }
      return unless rails_env(env) == 'development'
      return if env['ALLOW_DESTRUCTIVE_DB_TASKS'].to_s == '1'

      output.puts('Blocked potentially destructive db task in development environment.')
      output.puts("Requested tasks: #{tasks.join(', ')}")
      output.puts('If this is intentional, re-run with ALLOW_DESTRUCTIVE_DB_TASKS=1.')
      exit(1)
    end

    def self.abort_unless_test_env_for_specs!(env: ENV, output: $stderr)
      return if rails_env(env) == 'test'
      return if env['ALLOW_NON_TEST_SPECS'].to_s == '1'

      output.puts("Blocked specs because RAILS_ENV=#{rails_env(env).inspect}.")
      output.puts('Run specs with RAILS_ENV=test (default) to avoid touching development data.')
      output.puts('If this is intentional, re-run with ALLOW_NON_TEST_SPECS=1.')
      exit(1)
    end

    def self.abort_if_test_db_matches_development!(output: $stderr)
      return unless defined?(ActiveRecord::Base)

      # NOTE: we intentionally do NOT resolve the "development" side via
      # ActiveRecord::Base.configurations here. Each Rails env is meant to run
      # in its own container with its own .env.<env> file (see compose.yml),
      # so config/database.yml's `development:` section (which reads
      # ENV['MYSQL_DATABASE']) only reflects whatever dotenv file the CURRENT
      # process happens to have loaded. Inside the dedicated "test" container
      # that's .env.test, which made "development" look identical to "test"
      # even though .env.development declares a distinct database name and
      # development never actually runs there. Reading the declared value
      # straight from .env.development avoids that false positive.
      test_db = db_name_for(ActiveRecord::Base.configurations, 'test')
      development_db = declared_env_value('MYSQL_DATABASE', 'development')
      return if test_db.nil? || development_db.nil?
      return unless test_db == development_db

      output.puts('Unsafe database configuration detected: test and development DB names are identical.')
      output.puts("Both environments currently point to: #{test_db.inspect}")
      output.puts('Fix config/database.yml or environment variables before running tests.')
      exit(1)
    end

    def self.dangerous_db_task?(task_name)
      DANGEROUS_DB_TASK_PREFIXES.any? do |prefix|
        task_name == prefix || task_name.start_with?("#{prefix}:")
      end
    end
    private_class_method :dangerous_db_task?

    def self.rails_env(env)
      candidate = env['RAILS_ENV'].to_s
      candidate = env['RACK_ENV'].to_s if candidate.empty?
      candidate = 'development' if candidate.empty?
      candidate
    end
    private_class_method :rails_env

    def self.db_name_for(configurations, env_name)
      config = configurations.configs_for(env_name: env_name, name: 'primary') ||
               configurations.configs_for(env_name: env_name).first
      return nil unless config

      if config.respond_to?(:database)
        config.database.to_s
      else
        config.configuration_hash[:database].to_s
      end
    end
    private_class_method :db_name_for

    # Reads the literal value an environment's own .env.<rails_env> file
    # declares for +key+, ignoring whatever the current process' ENV holds.
    def self.declared_env_value(key, rails_env)
      return nil unless defined?(Rails) && Rails.respond_to?(:root) && Rails.root

      path = Rails.root.join(".env.#{rails_env}")
      return nil unless path.exist?

      File.foreach(path) do |line|
        line = line.strip
        next if line.empty? || line.start_with?('#')

        k, v = line.split('=', 2)
        return v.to_s.strip if k == key
      end
      nil
    end
    private_class_method :declared_env_value
  end
end

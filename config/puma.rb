# Load dev vars. These are loaded in application but puma needs them too.
require 'dotenv'
require 'os'

# Set vars as we cannot load them
app_dir = ENV['APP_PATH'] || '/var/www'

# Lock environment early so restart doesn't drift.
# .load has left-to-right precedence
rails_env = ENV.fetch('RAILS_ENV', 'development')
Dotenv.load(".env.#{rails_env}.local", '.env.local', ".env.#{rails_env}", '.env')

tag 'ENSL'

# Preload to save memory,
preload_app!

# Start in foreground mode
# daemonize false

# Set basic puma settings
environment rails_env

# if OS.posix?
#  bind "unix://#{app_dir}/tmp/sockets/puma.#{rails_env}.sock"
# end

port Integer(ENV['PUMA_PORT'] || 4000)

# Redirect stdout only in production. Dev mode needs it for debug
if rails_env.downcase != 'development'
  stdout_redirect "#{app_dir}/log/puma.stdout.log", \
                  "#{app_dir}/log/puma.stderr.log", true
end

pidfile "#{app_dir}/tmp/pids/puma.pid"
state_path "#{app_dir}/tmp/puma.state"

# FIXME: sometimes the app becomes super slow if workers are used, investigate
workers Integer(ENV['PUMA_WORKERS']) if ENV.has_key?('PUMA_WORKERS') && ENV['PUMA_WORKERS'].to_i > 0
worker_timeout Integer(ENV['PUMA_TIMEOUT'] || 30)
threads Integer(ENV['PUMA_MIN_THREADS'] || 1), Integer(ENV['PUMA_MAX_THREADS'] || 16)

# Allow restart via file
plugin :tmp_restart

if ENV['PUMA_WORKERS'] && ENV['PUMA_WORKERS'].to_i > 0
  before_worker_boot do
    require 'active_record'
    ActiveSupport.on_load(:active_record) do
      begin
        ActiveRecord::Base.connection.disconnect!
      rescue StandardError
        ActiveRecord::ConnectionNotEstablished
      end
      ActiveRecord::Base.establish_connection(YAML.safe_load("#{app_dir}/config/database.yml",
                                                             aliases: true)[rails_env])
    end
  end
end

# EXPLAIN This has been added here but why?
before_restart do
  if defined?(ActiveRecord::Base)
    begin
      ActiveRecord::Base.clear_active_connections!
    rescue StandardError
      # best-effort: avoid raising during puma restart
    end
  end
end

# Load dev vars
# FIXME: right dev file is not loaded
require "dotenv"
Dotenv.load()

tag 'ENSL'

# Preload to save memory,
preload_app!

# Start in foreground mode
daemonize false

# Rack up?
rackup DefaultRackup

# Set vars as we cannmot load them
rails_env = ENV['RAILS_ENV'] || 'development'
app_dir = ENV['DEPLOY_PATH'] || '/var/www'

# Set basic puma settings
environment rails_env
bind "unix://#{app_dir}/tmp/sockets/puma.sock"
port Integer(ENV['PUMA_PORT'] || 4000)

# Redirect stdout only in production. Dev mode needs it for debug
if rails_env.downcase != 'development'
  stdout_redirect "#{app_dir}/log/puma.stdout.log", \
                  "#{app_dir}/log/puma.stderr.log", true
end

pidfile "#{app_dir}/tmp/pids/puma.pid"
state_path "#{app_dir}/tmp/puma.state"

# FIXME: sometimes the app becomes super slow if workers are used, investigate
workers Integer(ENV['PUMA_WORKERS']) if (ENV.has_key?("PUMA_WORKERS") && ENV['PUMA_WORKERS'].to_i > 0)
worker_timeout Integer(ENV['PUMA_TIMEOUT'] || 30)
threads Integer(ENV['PUMA_MIN_THREADS']  || 1), Integer(ENV['PUMA_MAX_THREADS'] || 16)

# Allow restart via file
plugin :tmp_restart

on_worker_boot do
  require "active_record"
  ActiveSupport.on_load(:active_record) do
    ActiveRecord::Base.connection.disconnect! rescue ActiveRecord::ConnectionNotEstablished
    ActiveRecord::Base.establish_connection(YAML.load_file("#{app_dir}/config/database.yml")[rails_env])
  end
end

# EXPLAIN This has been added here but why?
on_restart do
  ENV["BUNDLE_GEMFILE"] = "#{app_dir}/Gemfile"
  Dotenv.overload
  ActiveRecord::Base.connection.disconnect!
end

require "dotenv"
Dotenv.load

base_path = (ENV['DEPLOY_PATH'] || Dir.pwd)
#current_path = "#{base_path}/current"
#shared_path = "#{base_path}/shared"
stderr_path = "#{base_path}/lpuma.stderr.log"
stdout_path = "#{base_path}/lpuma.stdout.log"

tag 'ENSL'

preload_app!
daemonize true
directory base_path
pidfile "#{base_path}/tmp/puma.pid"
state_path "#{base_path}/tmp/puma.state"
stdout_redirect stdout_path, stderr_path

environment ENV['RACK_ENV'] || 'production'
rackup DefaultRackup

bind "unix://#{base_path}/tmp/puma.sock"
port Integer(ENV['PUMA_PORT'] || 4000)

worker_timeout Integer(ENV['PUMA_TIMEOUT'] || 30)
workers Integer(ENV['PUMA_WORKERS'] || 4)
threads Integer(ENV['PUMA_MIN_THREADS']  || 1), Integer(ENV['PUMA_MAX_THREADS'] || 16)

on_worker_boot do
  ActiveSupport.on_load(:active_record) do
    ActiveRecord::Base.establish_connection
  end
end

on_restart do
  ENV["BUNDLE_GEMFILE"] = "#{current_path}/Gemfile"
  Dotenv.overload
  ActiveRecord::Base.connection.disconnect!
end

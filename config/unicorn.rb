require "dotenv"
Dotenv.load

base_path = (ENV['DEPLOY_PATH'] || Dir.pwd)
current_path = "#{base_path}/current"
shared_path = "#{base_path}/shared"

working_directory current_path
worker_processes Integer(ENV['UNICORN_WORKERS'] || 4)
timeout 30
preload_app true

user ENV['UNICORN_USER'], ENV['UNICORN_GROUP']
listen Integer(ENV['UNICORN_PORT']), :tcp_nopush => true
listen ENV['UNICORN_SOCKET'], :backlog => 64
 
stderr_path "#{shared_path}/log/unicorn.stderr.log"
stdout_path "#{shared_path}/log/unicorn.stdout.log"
pid "#{shared_path}/tmp/pids/unicorn.pid"

GC.respond_to?(:copy_on_write_friendly=) and GC.copy_on_write_friendly = true

before_exec do |server|
  ENV["BUNDLE_GEMFILE"] = "#{current_path}/Gemfile"
  Dotenv.overload
end

before_fork do |server, worker|
  ActiveRecord::Base.connection.disconnect!

  old_pid = "#{server.config[:pid]}.oldbin"
  if old_pid != server.pid
     begin
       sig = (worker.nr + 1) >= server.worker_processes ? :QUIT : :TTOU
       Process.kill(sig, File.read(old_pid).to_i)
     rescue Errno::ENOENT, Errno::ESRCH
     end
  end
end
 
after_fork do |server, worker|
  ActiveRecord::Base.establish_connection
end
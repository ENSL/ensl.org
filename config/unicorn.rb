base_path = "/var/www/virtual/ensl.org/deploy"
current_path = "#{base_path}/current"
shared_path = "#{base_path}/shared"

working_directory current_path
worker_processes Integer(ENV['UNICORN_WORKERS'] || 4)
timeout 30
preload_app true

user ENV['UNICORN_USER'], ENV['UNICORN_GROUP']
listen Integer(ENV['UNICORN_PORT'] || 4000), :tcp_nopush => true
listen ENV['UNICORN_SOCKET'], :backlog => 64
 
stderr_path "#{shared_path}/log/unicorn.stderr.log"
stdout_path "#{shared_path}/log/unicorn.stdout.log"
pid "#{shared_path}/tmp/pids/unicorn.pid"
 
before_fork do |server, worker|
  ActiveRecord::Base.connection.disconnect!
 
  old_pid = "#{server.config[:pid]}.oldbin"

  if File.exists?(old_pid) && server.pid != old_pid
    begin
      Process.kill('QUIT', File.read(old_pid).to_i)
    rescue Errno::ENOENT, Errno::ESRCH
    end
  end
end
 
after_fork do |server, worker|
  ActiveRecord::Base.establish_connection
end
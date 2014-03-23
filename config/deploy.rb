lock '3.1.0'

set :application, 'ensl'
set :scm, :git
set :repo_url, 'git@github.com:ENSL/ensl.org.git'
set :keep_releases, 10

set :linked_files, %w{config/database.yml}
set :linked_dirs, %w{bin log tmp/pids tmp/cache tmp/sockets vendor/bundle public/system}
set :normalize_asset_timestamps, %{public/images public/javascripts public/stylesheets}

set :rbenv_type, :user
set :rbenv_ruby, '2.1.1'

namespace :deploy do
  desc 'Restart application'
  task :restart do
    foreman.export
    foreman.restart
  end

  after :publishing, :restart
end

namespace :foreman do
  desc "Export the Procfile to Ubuntu's upstart scripts"
  task :export do
    on roles(:app) do |host|
      run "cd #{current_path} && #{sudo} foreman export upstart /etc/init -a #{app_name} -u #{user} -l #{fetch(:deploy_to)}/shared/log"
    end
  end

  desc "Start the application services"
  task :start do
    on roles(:app) do |host|
      run "#{sudo} service #{app_name} start"
    end
  end

  desc "Stop the application services"
  task :stop do
    on roles(:app) do |host|
      run "#{sudo} service #{app_name} stop"
    end
  end

  desc "Restart the application services"
  task :restart do
    on roles(:app) do |host|
      run "#{sudo} service #{app_name} start || #{sudo} service #{app_name} restart"
    end
  end
end
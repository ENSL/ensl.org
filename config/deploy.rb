lock '3.1.0'

set :application, 'ensl'
set :deploy_user, 'deploy'
set :pty, true

set :scm, :git
set :repo_url, 'git@github.com:ENSL/ensl.org.git'
set :keep_releases, 10

set :rbenv_type, :user
set :rbenv_ruby, '2.1.1'
set :rbenv_sudo, "sudo /home/#{fetch(:deploy_user)}/.rbenv/bin/rbenv sudo"

set :linked_files, %w{.env}
set :linked_dirs, %w{bin log tmp/pids tmp/cache tmp/sockets vendor/bundle 
                     public/system public/local public/uploads}

set :normalize_asset_timestamps, %{public/images public/javascripts public/stylesheets}

namespace :deploy do
  desc 'Restart application'
  task :restart do
    invoke 'foreman:export'
    invoke 'foreman:restart'
  end

  after :publishing, :restart
end

namespace :foreman do
  desc "Export the Procfile to Ubuntu's upstart scripts"
  task :export do
    on roles(:app) do |host|
      within release_path do
        execute "#{fetch(:rbenv_sudo)} bundle exec foreman export upstart /etc/init -a #{fetch(:application)} -u #{fetch(:deploy_user)} -l #{fetch(:deploy_to)}/shared/log"
      end
    end
  end

  desc "Start the application services"
  task :start do
    on roles(:app) do |host|
      execute "sudo service #{fetch(:application)} start"
    end
  end

  desc "Stop the application services"
  task :stop do
    on roles(:app) do |host|
      execute "sudo service #{fetch(:application)} stop"
    end
  end

  desc "Restart the application services"
  task :restart do
    on roles(:app) do |host|
      execute "sudo service #{fetch(:application)} start || #{sudo} service #{fetch(:application)} restart"
    end
  end
end
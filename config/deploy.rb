lock '3.1.0'

set :application, 'ensl'
set :deploy_via, :remote_cache
set :pty, true

set :scm, :git
set :repo_url, 'git@github.com:ENSL/ensl.org.git'
set :keep_releases, 10

set :rbenv_type, :user
set :rbenv_ruby, '2.1.1'
set :dotenv_role, [:app, :web]

set :unicorn_config_path, "config/unicorn.rb"

set :writable_dirs, %w{public tmp}
set :linked_files, %w{.env}
set :linked_dirs, %w{bin log tmp/pids tmp/cache tmp/sockets vendor/bundle 
                     public/system public/local public/uploads public/files}

set :normalize_asset_timestamps, %{public/images 
                                   public/javascripts
                                   public/stylesheets}

namespace :deploy do
  namespace :check do
    desc "Check write permissions"
    task :permissions do
      on roles(:all) do |host|
        fetch(:writable_dirs).each do |dir|
          path = "#{shared_path}/#{dir}"

          if test("[ -w #{path} ]")
            info "#{path} is writable on #{host}"
          else
            error "#{path} is not writable on #{host}"
          end
        end
      end
    end
  end

  task :restart do
    invoke 'unicorn:restart'
  end

  after :publishing, :restart
end
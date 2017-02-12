#lock '3.1.0'

set :application, 'ensl'
set :deploy_via, :remote_cache
set :pty, true

set :scm, :git
set :repo_url, 'https://github.com/ENSL/ensl.org.git'
set :keep_releases, 10

set :rbenv_type, :user
set :rbenv_ruby, '2.2.2'
set :bundle_flags, '--quiet'
set :dotenv_role, [:app, :web]

set :puma_config, -> { File.join(current_path, 'config', 'puma.rb') }
set :puma_pid, -> { File.join(shared_path, 'tmp', 'pids', 'puma.pid') }

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
    invoke 'puma:restart'
  end

  after :publishing, :restart
end

namespace :puma do
  desc "Start puma"
  task :start do
    on roles(:app) do
      within current_path do
        execute :bundle, 'exec', :puma, "-C #{fetch(:puma_config)}"
      end
    end
  end

  desc "Restart puma"
  task :restart do
    on roles(:app) do
      within current_path do
        if valid_pid?
          execute :kill, "-USR2 $( cat #{fetch(:puma_pid)} )"
        else
          execute :bundle, 'exec', :puma, "-C #{fetch(:puma_config)}"
        end
      end
    end
  end

  desc "Stop puma"
  task :stop do
    on roles(:app) do
      within current_path do
        if valid_pid?
          execute :kill, "-INT $( cat #{fetch(:puma_pid)} )"
        else
          warn 'Puma does not appear to be running'
        end
      end
    end
  end

  def valid_pid?
    test "[ -f #{fetch(:puma_pid)} ]" and test "kill -0 $( cat #{fetch(:puma_pid)} )"
  end
end

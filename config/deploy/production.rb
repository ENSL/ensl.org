set :branch, 'master'
set :deploy_to, '/var/www/virtual/ensl.org/deploy'

set :rails_env, 'production'
set :unicorn_rack_env, fetch(:rails_env)

role :app, %w{vu2009@ensl.org}
role :web, %w{vu2009@ensl.org}

server 'ensl.org', user: 'vu2009', roles: %w{web app}

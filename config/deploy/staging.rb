set :branch, 'feature-redesign'
set :deploy_to, '/var/www/virtual/ensl.org/staging/rails'

set :rails_env, 'staging'
set :unicorn_rack_env, fetch(:rails_env)

role :app, %w{vu2009@staging.ensl.org}
role :web, %w{vu2009@staging.ensl.org}

server 'staging.ensl.org', user: 'vu2009', roles: %w{web app}

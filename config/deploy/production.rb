set :branch, 'master'
set :rails_env, 'production'
set :unicorn_rack_env, fetch(:rails_env)

role :app, %w{vu2009@ensl.org}
role :web, %w{vu2009@ensl.org}
role :db,  %w{vu2009@ensl.org}

server 'ensl.org', user: 'vu2009', roles: %w{web app}

set :branch, 'master'
set :rails_env, 'production'
set :unicorn_rack_env, fetch(:rails_env)

role :app, %w{deploy@ensl.org}
role :web, %w{deploy@ensl.org}
role :db,  %w{deploy@ensl.org}

server 'ensl.org', user: 'deploy', roles: %w{web app}

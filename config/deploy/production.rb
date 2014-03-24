set :branch, 'master'
set :rails_env, 'production'

role :app, %w{deploy@ensl.org}
role :web, %w{deploy@ensl.org}
role :db,  %w{deploy@ensl.org}

server 'ensl.org', user: 'deploy', roles: %w{web app}

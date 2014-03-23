set :branch, 'master'
set :rails_env, 'production'

role :app, %w{deploy@ensl.org}
role :web, %w{deploy@ensl.org}
role :db,  %w{deploy@ensl.org}

set :deploy_to, '/var/www/virtual/ensl.org/deploy'

server 'ensl.org', user: 'deploy', roles: %w{web app}

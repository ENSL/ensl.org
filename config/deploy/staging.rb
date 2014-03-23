set :branch, 'develop'
set :rails_env, 'staging'

role :app, %w{deploy@staging.ensl.org}
role :web, %w{deploy@staging.ensl.org}
role :db,  %w{deploy@staging.ensl.org}

set :deploy_to, '/var/www/virtual/ensl.org/deploy'

server 'staging.ensl.org', user: 'deploy', roles: %w{web app}
#!/bin/bash

cd $APP_PATH

source script/env.sh .env .env.$RAILS_ENV .env.$RAILS_ENV.local .env.local

# Make sure we have all gems, this fixed some startup issues.
bundle config github.https true
bundle config set path '/var/bundle'
bundle install --jobs 8

# Precompile assets when needed. Don't assume the ENV
if [ "$ASSETS_PRECOMPILE" -eq 1 ]; then
  echo "Fetching assets..."
  # FIXME: disabled for now
  if false; then
  #if [[ -z "$ASSETS_PATH" ]] && [ -d "$ASSETS_PATH"]; then
    rm -rf "${APP_PATH}/public/assets"
    mv "$ASSETS_PATH" "${APP_PATH}/public/assets"
  else
    cd $APP_PATH
    bundle exec rake assets:clean
    bundle exec rake assets:precompile
  fi
  chown -R web:web $APP_PATH
fi

# Run migrations
bundle exec rake db:migrate

# Start puma
bundle exec puma -C config/puma.rb

# After puma dies, leave us a shell
/bin/bash

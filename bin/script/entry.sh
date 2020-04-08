#!/bin/bash

cd $APP_PATH

source script/env.sh .env .env.$RAILS_ENV .env.$RAILS_ENV.local .env.local

# Make sure we have all assets
bundle config github.https true
bundle config set path '/var/bundle'
bundle install --jobs 8

if [ "$ASSETS_PRECOMPILE" -eq 1 ]; then
  echo "Fetching assets..."
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

cd $APP_PATH
bundle exec puma -C config/puma.rb
bash

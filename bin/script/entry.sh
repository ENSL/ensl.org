#!/bin/bash
# Start the app
# RAILS_ENV needs to be set at minimum, this will allow it to load env variables from the named .env files.

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source $SCRIPT_DIR/../../script/env.sh .env .env.$RAILS_ENV .env.local .env.$RAILS_ENV.local 

cd $APP_PATH

# Create dirs
mkdir -p tmp/pids tmp/sockets tmp/sessions tmp/cache log

# Make sure we have all gems, this fixed some startup issues.
bundle config github.https true
bundle config set path '/var/bundle'
bundle install --jobs 8

# Precompile assets when needed. Don't assume the ENV
if [ "$ASSETS_PRECOMPILE" -eq 1 ]; then
  echo "Precompiling assets..."
  # FIXME: disabled for now because of issues
  # if [[ -z "$ASSETS_PATH" ]] && [ -d "$ASSETS_PATH"]; then
  #   rm -rf "${APP_PATH}/public/assets"
  #   mv "$ASSETS_PATH" "${APP_PATH}/public/assets"
  # fi
  bundle exec rake assets:clean
  bundle exec rake assets:precompile
  chown -R web:web $APP_PATH
fi

# Run migrations
bundle exec rake db:migrate

# Start puma unless disabled for debugging
if [[ "$DISABLE_PUMA" -eq 1 ]]; then
  echo "Puma is disabled, dropping to shell."
  /bin/bash -c "while true; do sleep 60; done"
  exit 0
fi

# Start puma in debug mode if needed
if [[ "$RAILS_DEBUG" -eq 1 ]]; then
  echo "Starting in developer mode with rdbg..."
  bundle exec rdbg --open --port 12345 -c -- puma -C config/puma.rb
  exit 0
fi

bundle exec puma -C config/puma.rb

# After puma dies, leave us a shell
/bin/bash

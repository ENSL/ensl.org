#!/bin/bash
# Start the app
# RAILS_ENV needs to be set at minimum, this will allow it to load env variables from the named .env files.

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
# Runtime path; QLTY does not pass this dependency to ShellCheck.
# shellcheck disable=SC1091
source "$SCRIPT_DIR"/env.sh .env .env."$RAILS_ENV" .env.local .env."$RAILS_ENV".local 

cd "$APP_PATH" || exit

# Create dirs
mkdir -p tmp/pids tmp/sockets tmp/sessions tmp/cache log

# Keep Bundler from mutating the mounted app tree at runtime. Production images
# should already have gems installed during the image build.
export BUNDLE_PATH=/var/bundle

if [[ "$RAILS_ENV" == "development" ]]; then
  bundle install
else
  export BUNDLE_FROZEN=1
  if ! bundle check >/dev/null 2>&1; then
    echo "Bundler gems are missing or inconsistent for $RAILS_ENV; rebuild the image or run bundle install in a writable environment."
    exit 1
  fi
fi

# Run migrations and run sleep loop on failure
echo "Running database migrations..."
bundle exec rake db:migrate || {
  echo "Database migrations failed, dropping to shell."
  /bin/bash -c "while true; do sleep 60; done"
  exit 1
}

# Precompile assets when needed. Don't assume the ENV
if [ "$ASSETS_PRECOMPILE" -eq 1 ]; then
  echo "Precompiling assets..."
  bundle exec rake assets:clean
  bundle exec rails dartsass:build
  bundle exec rails tailwindcss:build
  bundle exec rails assets:precompile
fi

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

# If in development, start with Tailwind runner
if [[ "$RAILS_ENV" == "development" ]]; then
  echo "Starting Tailwind runner in development mode..."
  bin/dev
else
  bundle exec puma -C config/puma.rb
fi


# After puma dies, leave us a shell
/bin/bash

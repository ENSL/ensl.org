#!/bin/bash

cd /var/www

source script/env.sh .env .env.$RAILS_ENV .env.$RAILS_ENV.local .env.local

# Make sure we have all assets
su -c "bundle config github.https true; cd $DEPLOY_PATH && bundle install --path /var/bundle --jobs 4" -s /bin/bash -l web

if [ -z $ASSETS_PRECOMPILE ] && [ $ASSETS_PRECOMPILE -eq 1 ]; then
  if [[ -z "$ASSETS_PATH" ]] && [ -d "$ASSETS_PATH"]; then
    rm -rf "${DEPLOY_PATH}/public/assets"
    mv "$ASSETS_PATH" "${DEPLOY_PATH}/public/assets"
  else
    su -c "cd $DEPLOY_PATH && bundle assets:precompile" -s /bin/bash -l web
  fi
  chown -R web:web $DEPLOY_PATH
fi

su -c "cd $DEPLOY_PATH && bundle exec puma -C config/puma.rb" -s /bin/bash -l web
bash

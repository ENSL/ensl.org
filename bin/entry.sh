#!/bin/bash

cd /var/www

source /var/www/.env

if [ $RAILS_ENV = "production" ]; then
  rm -rf /var/www/public/assets
  mv /home/web/assets /var/www/public/
  chown -R web:web /var/www
fi

su -c "bundle config github.https true; cd /var/www && bundle install --path /var/bundle --jobs 4" -s /bin/bash -l web
su -c "cd /var/www && bundle exec puma -C config/puma.rb" -s /bin/bash -l web
bash

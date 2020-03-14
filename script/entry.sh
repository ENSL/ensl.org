#!/bin/bash

cd /var/www
chown -R web:web /var/www

su -c "bundle config github.https true; cd /var/www && bundle install --path /var/bundle --jobs 4" -s /bin/bash -l web
su -c "cd /var/www && bundle exec puma -C config/puma.rb" -s /bin/bash -l web
bash

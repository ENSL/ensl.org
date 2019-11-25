#!/bin/bash

env
cd /var/www
source /var/www/.env
rm -rf /var/www/public/assets
mv /home/web/assets /var/www/public/
chown -R web:web /var/www/public

LOG_FILE = "/var/www/log/$RAILS_ENV.log"
touch $LOG_FILE
chown web:web $LOG_FILE

su -c "cd /var/www && bundle exec rake assets:precompile" -s /bin/bash -l web
su -c "cd /var/www && bundle exec puma -C config/puma.rb" -s /bin/bash -l web

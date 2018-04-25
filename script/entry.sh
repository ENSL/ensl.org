#!/bin/bash

env
cd /var/www
source /var/www/.env
rm -rf /var/www/public/assets
mv /home/web/assets /var/www/public/
chown -R web:web /var/www/public

#bundle exec rake assets:precompile
su -c "cd /var/www && bundle exec puma -C config/puma.rb" -s /bin/bash -l web

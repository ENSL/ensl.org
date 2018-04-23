#!/bin/bash

env
cd /var/www
source /var/www/.env
rm -rf /var/www/public/assets
mv /var/www/assets_tmp /var/www/public/
bundle exec puma -C config/puma.rb

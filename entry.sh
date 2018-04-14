#!/bin/bash

env|grep -i MYSQL
cd /var/www
bundle exec rake assets:precompile
bundle exec puma -C config/puma.rb

#!/bin/bash

env
cd /var/www
source .env
bundle exec rake assets:precompile
bundle exec puma -C config/puma.rb

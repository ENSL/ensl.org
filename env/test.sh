#!/bin/bash

export RACK_ENV=test
export RAILS_ENV=test
export APP_SECRET=e0cdcb729c4b21d5259e957a2ffc13a3

export DEPLOY_PATH=/var/www

export PUMA_WORKERS=1
export PUMA_MIN_THREADS=1
export PUMA_MAX_THREADS=16
export PUMA_PORT=3000
export PUMA_TIMEOUT=30

#export MYSQL_HOST="${MYSQL_PORT_3306_TCP_ADDR:-localhost}"
export MYSQL_DATABASE=ensl
export MYSQL_USER=root
export MYSQL_HOST="mysql"
export MYSQL_USERNAME=root
export MYSQL_ROOT_PASSWORD=test
export MYSQL_PASSWORD=test
export MYSQL_ROOT_HOST=172.%
export MYSQL_CONNECTION_POOL=32

exec "$@"

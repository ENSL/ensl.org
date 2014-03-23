# Ubuntu 13.10 x64

## Capistrano setup

SSH as root, and install the basics

    sudo apt-get update
    sudo apt-get upgrade

Create a deploy user. Disable password authentication and add it to the www-data group.

    sudo adduser deploy
    sudo passwd -l deploy
    sudo usermod -a -G www-data deploy

Add the following to `/etc/sudoers` to allow the `deploy` user to manage nginx and foreman via sudo without a password
  
    # /etc/sudoers
    Cmnd_Alias START_FOREMAN = /sbin/start foreman

    deploy ALL=NOPASSWD:START_FOREMAN
    deploy ALL=NOPASSWD:/etc/init.d/nginx

## Install MySQL & Memcached

    sudo apt-get install mysql-server mysql-client libmysqlclient-dev memcached

Login to mysql as root, and create the database and user account:

    CREATE DATABASE `ensl`;
    CREATE USER 'xxx'@'localhost' IDENTIFIED BY 'xxx';
    GRANT ALL PRIVILEGES ON ensl.* TO 'xxx'@'localhost' WITH GRANT OPTION;

## Install rbenv, ruby, bundler and Image Magick

As root, install dependencies

    sudo apt-get install nginx git-core curl zlib1g-dev build-essential libssl-dev libreadline-dev libyaml-dev libsqlite3-dev sqlite3 libxml2-dev libxslt1-dev libmysql-ruby imagemagick libmagickwand-dev

Switch user to deploy, and install rbenv

    su deploy
    cd ~
    git clone git://github.com/sstephenson/rbenv.git .rbenv
    echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
    echo 'eval "$(rbenv init -)"' >> ~/.bashrc
    exec $SHELL

    git clone git://github.com/sstephenson/ruby-build.git ~/.rbenv/plugins/ruby-build
    echo 'export PATH="$HOME/.rbenv/plugins/ruby-build/bin:$PATH"' >> ~/.bashrc
    exec $SHELL

    rbenv install 2.1.1
    rbenv global 2.1.1

    echo "gem: --no-ri --no-rdoc" > ~/.gemrc
    gem install bundler

## Install the ENSL site

Create the `.env` file with the appropriate credentials.

    mkdir /var/www/virtual/ensl.org/deploy
    mkdir /var/www/virtual/ensl.org/deploy/shared
    touch /var/www/virtual/ensl.org/deploy/shared/.env
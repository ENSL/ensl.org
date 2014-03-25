# Production Install (Ubuntu 13.10 x64 or Debian 7)

## Capistrano setup

SSH as a user with sudo access, update package lists and upgrade packages (new install only)

    sudo apt-get update
    sudo apt-get upgrade

Either use an existing sandboxed user account, or create a deploy user and disable password authentication. Instead, authenticate with a keypair.

    sudo adduser deploy
    sudo passwd -l deploy

## Install Apache

    sudo apt-get install apache2 apache2-mpm-prefork

Now create the required directories, e.g. `/var/www/virtual/ensl.org/deploy`

## Install MySQL & Memcached

You may need to re-configure MySQL. Use `sudo dpkg-reconfigure mysql-server-5.5`

    sudo apt-get install mysql-server mysql-client libmysqlclient-dev memcached

Login to mysql as root, and create the database and user account:

    CREATE DATABASE `ensl`;
    CREATE USER 'xxx'@'localhost' IDENTIFIED BY 'xxx';
    GRANT ALL PRIVILEGES ON ensl.* TO 'xxx'@'localhost' WITH GRANT OPTION;

## Install rbenv, ruby, bundler and Image Magick

As a user with sudo, install dependencies

    sudo apt-get install git-core curl zlib1g-dev build-essential libssl-dev libreadline-dev libyaml-dev libsqlite3-dev sqlite3 libxml2-dev libxslt1-dev imagemagick libmagickwand-dev

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

    touch /var/www/virtual/ensl.org/deploy/shared/.env

# Deployment

Use capistrano to deploy:
    
    bundle exec cap production deploy
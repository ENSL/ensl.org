# Install (Ubuntu LTS)

ENSL Website is fairly easy to run.

## 1. Install requirements: docker, docker-compose and git

https://docs.docker.com/install/
https://docs.docker.com/compose/install/

Install docker + docker-compose:

    wget -O - 'https://get.docker.com/'|bash
    sudo curl -L https://github.com/docker/compose/releases/download/1.18.0/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose

Install git: https://git-scm.com/book/en/v2/Getting-Started-Installing-Git

    sudo apt-get install git

## 2. Download ENSL website and install it

Now create the required directories, e.g. `/srv/ensl.org`

    git clone git@github.com:ENSL/ensl.org.git

First select your environment (eg. development). Then use a script to load the env vars to your shell env:

    source script/env.sh .env .env.development

Second build the ENSL docker containers.

    docker-compose build

Put any database dumps to `db/initdb.d`.

a) Then start for **production**:
    
    docker-compose up

b) ... or start for **development**:

    docker-compose -f docker-compose.yml up

## 3. Install reverse proxy (production only)

Install apache, nginx etc. reverse proxy. It will take requests from the users and pass them to ENSL website. Sample configuration availble @ ext/nginx.

https://www.nginx.com/resources/wiki/start/

    sudo apt-get install nginx

*Skip this step if you are only doing development.*

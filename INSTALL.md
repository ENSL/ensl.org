# Install (Ubuntu LTS)

ENSL Website is fairly easy to run.

## 1. Install requirements: docker, docker-compose and git

https://docs.docker.com/install/
https://docs.docker.com/compose/install/

Install docker + docker-compose:

    wget -O - 'https://get.docker.com/'|bash
    sudo curl -L https://github.com/docker/compose/releases/download/1.18.0/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose

Install git: https://git-scm.com/book/en/v2/Getting-Started-Installing-Git

    sudo apt-get install nginx

## 3. Download ENSL website and install it

Now create the required directories, e.g. `/srv/ensl.org`

    git clone git@github.com:ENSL/ensl.org.git

Create the `.env` file by copying `.env.example` with the appropriate credentials.

    cd $PATH_TO_WEBSITE && cp .env.example .env
    vim .env

If the database does not exist, it will be created with settings from .env file so make sure you configure it.

Finally, Start the docker containers.

    docker-compose build
    docker-compose --rm up

## 4. Install reverse proxy (production only)

Install apache, nginx etc. reverse proxy. It will take requests from the users and pass them to ENSL website. Sample configuration availble @ ext/nginx.

https://www.nginx.com/resources/wiki/start/

    sudo apt-get install nginx

*Skip this step if you are only doing development.*

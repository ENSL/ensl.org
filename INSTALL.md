# Install (Ubuntu LTS)

ENSL Website is fairly easy to run.

### 1. Install requirements: docker, docker-compose and git

https://docs.docker.com/install/
https://docs.docker.com/compose/install/

Install docker + docker-compose:

    wget -O - 'https://get.docker.com/'|bash
    sudo curl -L https://github.com/docker/compose/releases/download/1.18.0/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose

Install git: https://git-scm.com/book/en/v2/Getting-Started-Installing-Git

    sudo apt-get install git

### 2. Download ENSL website and install it

    git clone git@github.com:ENSL/ensl.org.git

### 3. Build the ENSL docker containers.

    cd ensl.org
    docker-compose build

### 4. Put any database dumps to `db/initdb.d`. (optional)

You can use `script/db_dump.sh` to dump production database.

    mysqldump --opt -h DATABASE_IP -u USERNAME DATABASE_NAME > 00_ensl.org.`date +%F`.sql
    mv 00_ensl.org.`date +%F`.sql db/initdb.d/00_ensl.org.`date +%F`.sql

You need to manually copy it to staging database on same db server for now.

### 5. Load the env vars to your shell env:

    source script/env.sh .env .env.production

### 6. Then start the whole thing

    docker-compose up production
    docker-compose down

### 7. Install reverse proxy (production only)

a) The docker-compose contains basic nginx setup. It's in docker-compose. Use that.

b) If you have your own NGINX setup, just use the sample site file from the ext/nginx.conf.d

https://www.nginx.com/resources/wiki/start/

    sudo apt-get install nginx

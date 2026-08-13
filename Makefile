REGISTRY ?= ensl
PROJECT  ?= ensl.org
TAG      ?= latest

ifdef REGISTRY
  IMAGE=$(REGISTRY)/$(PROJECT):$(TAG)
else
  IMAGE=$(PROJECT):$(TAG)
endif

all:
	@echo "Available targets:"
	@echo "  * build - build a Docker image for $(IMAGE)"
	@echo "  * pull  - pull $(IMAGE)"
	@echo "  * push  - push $(IMAGE)"
	@echo "  * test  - build and test $(IMAGE)"
	@echo "  * deploy_check - run production pre-deploy MySQL integrity checks"
	@echo "  * perms - fix app/files/db/dkim permissions for mounted volumes"
	@echo "  * prep_prod - checkout master and build production+sidekiq images for production profile"
	@echo "  * deploy_prod - start missing prod deps without restart, then recreate production app/worker containers"
	@echo "  * restart_prod_all - recreate full production stack without rebuilding images"

build: Dockerfile
	docker build -t $(IMAGE) .

pull:
	docker pull $(IMAGE) || true

push:
	docker push $(IMAGE)

prep_prod:
	git fetch origin
	git checkout origin/master
	bash -lc '\
	  source ./script/env.sh .env .env.production .env.local && \
	  docker compose --profile production build production sidekiq\
	'

deploy_prod:
	bash -lc '\
	  source ./script/env.sh .env .env.production .env.local && \
	  docker compose --profile production up -d \
	    --no-recreate \
	    --no-build \
	    db redis smtp && \
	  docker compose --profile production rm -sf production sidekiq && \
	  docker compose --profile production up -d \
	    --no-deps \
	    --force-recreate \
	    --no-build \
	    --remove-orphans \
	    production sidekiq\
	'

deploy_check:
	bash ./script/deploy_check.sh .env .env.production .env.local

perms:
	bash -lc '\
	  set -e && \
	  source ./script/env.sh .env .env.$${RAILS_ENV:-development} .env.local .env.$${RAILS_ENV:-development}.local && \
	  docker run --rm -u root \
	    -v "$$PWD:/var/www" \
	    -v "$${FILES_HOST_ROOT}:$${FILES_ROOT}" \
	    alpine:3.22 /bin/sh -ec "\
	      mkdir -p /var/www/tmp/pids /var/www/tmp/sockets /var/www/tmp/sessions /var/www/tmp/cache /var/www/log /var/www/public/local /var/www/public/assets \"$${FILES_ROOT}\" && \
	      chown -R $${WEB_UID:-1000}:$${WEB_GID:-1000} /var/www/tmp /var/www/log /var/www/public/local /var/www/public/assets \"$${FILES_ROOT}\" && \
	      chmod -R u+rwX,g+rwX /var/www/tmp /var/www/log /var/www/public/local /var/www/public/assets \"$${FILES_ROOT}\"" && \
	  docker run --rm -u root \
	    -v "$$PWD/db/data:/var/lib/mysql" \
	    mariadb:10.7 /bin/sh -ec "\
	      mkdir -p /var/lib/mysql && \
	      chown -R mysql:mysql /var/lib/mysql && \
	      chmod 0700 /var/lib/mysql" && \
	  docker run --rm -u root \
	    -v "$$PWD/ext/dkim:/etc/opendkim/keys" \
	    mwader/postfix-relay:latest /bin/sh -ec "\
	      mkdir -p /etc/opendkim/keys && \
	      chown -R opendkim:opendkim /etc/opendkim/keys && \
	      find /etc/opendkim/keys -type d -exec chmod 0755 {} + && \
	      find /etc/opendkim/keys -type f -name '*.private' -exec chmod 0600 {} + && \
	      find /etc/opendkim/keys -type f ! -name '*.private' -exec chmod 0644 {} +"\
	'

restart_prod_all:
	bash -lc '\
	  source ./script/env.sh .env .env.production .env.local && \
	  docker compose --profile production down --remove-orphans && \
	  docker compose --profile production up -d \
	    --force-recreate \
	    --no-build \
	    --pull always \
	    --remove-orphans\
	'

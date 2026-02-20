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
	@echo "  * prep_prod - checkout master and build production+sidekiq images for production profile"
	@echo "  * deploy_prod - recreate only production app/worker containers (keeps db/redis running)"
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
	  docker compose --profile production rm -sf production sidekiq && \
	  docker compose --profile production up -d \
	    --no-deps \
	    --force-recreate \
	    --no-build \
	    --pull always \
	    --remove-orphans \
	    production sidekiq\
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

test: build
	fig run web ./env/test.sh ./test.sh


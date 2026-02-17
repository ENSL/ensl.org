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
	@echo "  * prep_prod - prepare production image by checking out master and building with production profile"

build: Dockerfile
	docker build -t $(IMAGE) .

pull:
	docker pull $(IMAGE) || true

push:
	docker push $(IMAGE)

prep_prod:
	git fetch origin
	git checkout origin/master
	docker compose --profile production build production

deploy_prod:
	docker compose --profile production down --remove-orphans
	bash -lc 'source ./script/env.sh .env .env.production .env.local && docker compose --profile production up -d --build --pull always --remove-orphans production'

test: build
	fig run web ./env/test.sh ./test.sh


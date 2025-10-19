VERSION ?= v0.0.1

PORT ?= 8000

CONTAINER_CMD := docker
DEV_CONTAINER_IMG := dev-docker-build
PROD_CONTAINER_IMG := bruttazz/apod-api:$(VERSION)



help:	## Show all Makefile targets.
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' Makefile | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[33m%-30s\033[0m %s\n", $$1, $$2}'

test: $(DEV_CONTAINER_IMG)	## Run unit tests
	@$(CONTAINER_CMD) run -it --rm -v ./src:/opt/app:ro -w /opt/app --entrypoint resty $(DEV_CONTAINER_IMG) tests.lua

shell: $(DEV_CONTAINER_IMG)	## Get resty shell
	@$(CONTAINER_CMD) run -it --rm -v ./src:/opt/app:ro -v ./var:/var/app/www -w /opt/app --entrypoint sh $(DEV_CONTAINER_IMG)

build:  ## Build prod
	$(CONTAINER_CMD) rmi $(PROD_CONTAINER_IMG) || true
	$(CONTAINER_CMD) build -f Dockerfile -t $(PROD_CONTAINER_IMG) .
	touch build

run: build ## Run production docker build
	- $(CONTAINER_CMD) run --rm -p $(PORT):8000 -e SERVICE_BASE_URL=http://localhost:8000 $(PROD_CONTAINER_IMG)

run-b: ## Build and run
	$(RM) build
	$(MAKE) run

$(DEV_CONTAINER_IMG):
	$(CONTAINER_CMD) build -f Dockerfile.dev . -t $(DEV_CONTAINER_IMG)
	@touch $(DEV_CONTAINER_IMG)

clean-builds:
	$(CONTAINER_CMD) rmi $(DEV_CONTAINER_IMG) || true
	$(CONTAINER_CMD) rmi $(PROD_CONTAINER_IMG) || true

clean:	## Clean all build deps
	$(RM) build
	$(RM) $(DEV_CONTAINER_IMG)
	$(MAKE) clean-builds

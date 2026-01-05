VERSION ?= v1.0.3

PORT ?= 8000

CONTAINER_CMD := docker
DEV_CONTAINER_IMG := dev-docker-build
PROD_CONTAINER_IMG := bruttazz/apod-api:$(VERSION)



help:	## Show all Makefile targets.
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' Makefile | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[33m%-30s\033[0m %s\n", $$1, $$2}'

test: $(DEV_CONTAINER_IMG)	## Run unit tests
	@$(CONTAINER_CMD) run --rm -v ./src:/opt/app:ro -w /opt/app --entrypoint resty $(DEV_CONTAINER_IMG) tests.lua

shell: $(DEV_CONTAINER_IMG)	## Get resty shell
	@$(CONTAINER_CMD) run -it --rm -v ./src:/opt/app:ro -v ./var:/var/app/www -w /opt/app --entrypoint sh $(DEV_CONTAINER_IMG)

build:  ## Build prod
	$(CONTAINER_CMD) rmi $(PROD_CONTAINER_IMG) || true
	@echo "Building x86_64 images----------"
	$(CONTAINER_CMD) build -f Dockerfile --platform linux/amd64 -t $(PROD_CONTAINER_IMG)-amd64 .
	@echo "Building arm64 images----------"
	$(CONTAINER_CMD) build -f Dockerfile --platform linux/arm64 -t $(PROD_CONTAINER_IMG)-arm64 .
	touch build

push: build ## Push image
	@echo "Pushing buids"
	$(CONTAINER_CMD) push $(PROD_CONTAINER_IMG)-amd64
	$(CONTAINER_CMD) push $(PROD_CONTAINER_IMG)-arm64

	@echo "Building image manifest list"
	$(CONTAINER_CMD) manifest create $(PROD_CONTAINER_IMG) $(PROD_CONTAINER_IMG)-amd64 $(PROD_CONTAINER_IMG)-arm64
	$(CONTAINER_CMD) manifest annotate --arch amd64 $(PROD_CONTAINER_IMG) $(PROD_CONTAINER_IMG)-amd64
	$(CONTAINER_CMD) manifest annotate --arch arm64 $(PROD_CONTAINER_IMG) $(PROD_CONTAINER_IMG)-arm64
	$(CONTAINER_CMD) manifest push $(PROD_CONTAINER_IMG)

run: build ## Run production docker build
	- $(CONTAINER_CMD) run -it --rm -p $(PORT):8000 -e SERVICE_BASE_URL=http://localhost:8000 $(PROD_CONTAINER_IMG)

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

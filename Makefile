PORT ?= 8000
HOST ?= 0.0.0.0
WORKERS ?= 4

PYTHON ?= .venv/bin/python

help:	## Show all Makefile targets.
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' Makefile | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[33m%-30s\033[0m %s\n", $$1, $$2}'

.venv: requirements.txt
	- python3 -m venv .venv
	- $(PYTHON) -m pip install -r requirements.txt

run: .venv	## Run server
	@$(PYTHON) -m uvicorn server:app  --host $(HOST) --port $(PORT) --workers $(WORKERS) $(FLAGS)

dev: .venv	## Run dev server
	@$(MAKE) run WORKERS=1 FLAGS='--reload'

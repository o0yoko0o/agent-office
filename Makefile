# agent-office in Docker: one interface over docker compose, nothing installed
# on the host. `make` lists the targets. Settings come from .env (copied from
# .env.dist on first use).

SHELL := /bin/bash
.DEFAULT_GOAL := help

-include .env
export

HOST_PORT ?= 4848
BIND_IP ?= 127.0.0.1
# Host time zone for the container, e.g. Europe/Berlin (macOS and Linux).
TZ ?= $(shell readlink /etc/localtime 2>/dev/null | sed 's|.*/zoneinfo/||')
URL := http://$(if $(filter 0.0.0.0,$(BIND_IP)),127.0.0.1,$(BIND_IP)):$(HOST_PORT)
COMPOSE := docker compose -f compose.yaml -f compose.mounts.yaml
NPM_CI := npm ci --no-audit --no-fund

.PHONY: help env-check docker-check mounts build rebuild up down restart logs status shell open typecheck test native

help: ## List the targets
	@grep -hE '^[a-zA-Z_-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  \033[36m%-13s\033[0m %s\n", $$1, $$2}'

env-check: ## Create .env from .env.dist if it is missing
	@[ -f .env ] || { cp .env.dist .env; echo "Created .env from .env.dist"; }

docker-check: ## Check that Docker is running
	@docker info >/dev/null 2>&1 || { echo "Docker is not running. Start Docker Desktop first."; exit 1; }

compose.mounts.yaml:
	@scripts/docker/mounts.sh $@

mounts: ## Regenerate compose.mounts.yaml from the agent folders that exist
	@scripts/docker/mounts.sh compose.mounts.yaml

build: env-check docker-check compose.mounts.yaml ## Build the image
	$(COMPOSE) build office

rebuild: env-check docker-check compose.mounts.yaml ## Build the image without cache
	$(COMPOSE) build --no-cache office

up: env-check docker-check mounts ## Start the office and print its URL
	@if [ -z "$$($(COMPOSE) ps -q office 2>/dev/null)" ] && (exec 3<>/dev/tcp/127.0.0.1/$(HOST_PORT)) 2>/dev/null; then \
		echo "Port $(HOST_PORT) is already in use. Set HOST_PORT in .env."; exit 1; fi
	$(COMPOSE) up -d --wait office
	@echo "Office running at $(URL)"

down: docker-check compose.mounts.yaml ## Stop and remove the container
	$(COMPOSE) down

restart: down up ## Stop, then start again

logs: docker-check compose.mounts.yaml ## Follow the office's logs
	$(COMPOSE) logs -f office

status: docker-check compose.mounts.yaml ## Container state and a request to the office
	@$(COMPOSE) ps office
	@curl -fsS -o /dev/null $(URL)/api/snapshot && echo "$(URL) answers" || echo "$(URL) does not answer"

shell: docker-check compose.mounts.yaml ## Shell in the running container
	$(COMPOSE) exec office sh

open: ## Open the office in the browser
	@open $(URL) 2>/dev/null || xdg-open $(URL)

typecheck: docker-check compose.mounts.yaml ## npm run typecheck in a Node container
	$(COMPOSE) run --rm dev sh -c "$(NPM_CI) && npm run typecheck"

test: docker-check compose.mounts.yaml ## npm test in a Node container
	$(COMPOSE) run --rm dev sh -c "$(NPM_CI) && npm test"

native: ## Without Docker: npm run dev (needs Node and npm ci on the host)
	npm run dev

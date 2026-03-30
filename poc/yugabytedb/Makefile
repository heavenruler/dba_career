.PHONY: help init wait status logs sql destroy destroy-all restart

PODMAN := podman
COMPOSE := $(PODMAN) compose
DOCKER_CONFIG_DIR := /tmp/podman-docker-config
COMPOSE_ENV := DOCKER_CONFIG=$(DOCKER_CONFIG_DIR)
CONTAINER := yugabytedb-local
YSQL_CMD := $(PODMAN) exec -it $(CONTAINER) ysqlsh -h 127.0.0.1 -p 5433 -U yugabyte -d yugabyte

help:
	@printf '%s\n' \
	  'make init        Start YugabyteDB POC environment' \
	  'make wait        Wait until YSQL is ready' \
	  'make status      Show compose and port status' \
	  'make logs        Tail YugabyteDB logs' \
	  'make sql         Open ysqlsh shell' \
	  'make destroy     Stop environment' \
	  'make destroy-all Stop environment and remove volume' \
	  'make restart     Recreate environment'

init:
	@mkdir -p "$(DOCKER_CONFIG_DIR)"
	@$(PODMAN) machine start >/dev/null 2>&1 || true
	@$(COMPOSE_ENV) $(COMPOSE) up -d
	@$(MAKE) wait

wait:
	@i=1; \
	until $(PODMAN) exec $(CONTAINER) ysqlsh -h 127.0.0.1 -p 5433 -U yugabyte -d yugabyte -c 'select 1' >/dev/null 2>&1; do \
	  if [ $$i -gt 24 ]; then \
	    printf '%s\n' 'YugabyteDB is not ready after 120 seconds'; \
	    exit 1; \
	  fi; \
	  printf '%s\n' 'Waiting for YugabyteDB YSQL...'; \
	  i=$$((i + 1)); \
	  sleep 5; \
	done
	@printf '%s\n' 'YugabyteDB YSQL is ready'

status:
	@$(COMPOSE_ENV) $(COMPOSE) ps
	@$(PODMAN) port $(CONTAINER)

logs:
	@$(COMPOSE_ENV) $(COMPOSE) logs -f yugabytedb

sql:
	@$(YSQL_CMD)

destroy:
	@$(COMPOSE_ENV) $(COMPOSE) down

destroy-all:
	@$(COMPOSE_ENV) $(COMPOSE) down -v

restart: destroy init

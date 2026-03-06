SHELL := /usr/bin/env bash

SCENARIO ?=
SCENARIO_DIR := scenarios/$(SCENARIO)

.PHONY: help init up down reset verify logs list

help:
	@echo "Usage:"
	@echo "  make init"
	@echo "  make up SCENARIO=<name>"
	@echo "  make down SCENARIO=<name>"
	@echo "  make reset SCENARIO=<name>"
	@echo "  make verify SCENARIO=<name>"
	@echo "  make logs SCENARIO=<name>"
	@echo "  make list"

list:
	@find scenarios -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort

init:
	@./bin/init.sh

up:
	@./bin/up.sh $(SCENARIO)

down:
	@./bin/down.sh $(SCENARIO)

reset:
	@./bin/reset.sh $(SCENARIO)

verify:
	@./bin/doctor.sh $(SCENARIO)

logs:
	@./bin/logs.sh $(SCENARIO)

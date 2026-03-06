SHELL := /bin/bash

SCENARIO ?= redis-standalone

.PHONY: help init doctor up down reset verify logs

help:
	@printf "Usage:\n"
	@printf "  make init\n"
	@printf "  make doctor\n"
	@printf "  make up SCENARIO=<name>\n"
	@printf "  make down SCENARIO=<name>\n"
	@printf "  make reset SCENARIO=<name>\n"
	@printf "  make verify SCENARIO=<name>\n"
	@printf "  make logs SCENARIO=<name>\n"

init:
	@./bin/init.sh

doctor:
	@./bin/doctor.sh

up:
	@./bin/up.sh "$(SCENARIO)"

down:
	@./bin/down.sh "$(SCENARIO)"

reset:
	@./bin/reset.sh "$(SCENARIO)"

verify:
	@./scenarios/$(SCENARIO)/verify.sh

logs:
	@./bin/up.sh --logs "$(SCENARIO)"

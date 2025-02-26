# ##
# Philosophy of creating this Makefile
# ------------------------------------
# Make is used to ease development and simplify running repetitive tasks.
# But developers using it should know about what's being run under the hood
# and be able to run it themselves.
# This also prevent the case when a developer run a target thinking it has
# some specific arguments while it's not the case.
# That's why every target display the executed command before running it.
# ##

XDEBUG_SERVER_NAME = symfony
ifneq ($(wildcard ./.env),)
    include .env
    export
endif
ifneq ($(wildcard ./.env.local),)
	include .env.local
	export
endif
ifneq ($(APP_ENV),)
	ifneq ($(wildcard ./.env.$(APP_ENV)),)
		include .env.$(APP_ENV)
		export
	endif
	ifneq ($(wildcard ./.env.$(APP_ENV).local),)
		include .env.$(APP_ENV).local
		export
	endif
endif

CONT_IS_RUNNING = 1

ifneq ("$(wildcard /.dockerenv)", "")
IS_IN_DOCKER = 1
else
IS_IN_DOCKER = 0

ifeq ($(shell docker compose ps -q php 2>/dev/null),)
CONT_IS_RUNNING = 0
endif

# Executables (local)
DOCKER_COMP = docker compose

# Docker containers
PHP_CONT = $(DOCKER_COMP) exec php
endif

# Misc
.DEFAULT_GOAL = help

## —— 🎵 🐳 The Symfony Docker Makefile 🐳 🎵 ——————————————————————————————————
.PHONY: help
help: ## Outputs this help screen
	@grep -h -E '(^[a-zA-Z0-9\./_-]+:.*?##.*$$)|(^##[^#<>])' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}{printf "\033[38;5;2m%-30s\033[39m %s\n", $$1, $$2}' | sed -e 's/\[38;5;2m##/[38;5;3m/'

## —— Docker 🐳 ————————————————————————————————————————————————————————————————
# tips: using a - prefix to define this target as internal
-ensure-container-is-up:
ifeq ($(CONT_IS_RUNNING), 0)
-ensure-container-is-up: up
endif

ifeq ($(IS_IN_DOCKER), 1)
.PHONY: bash build build-dev debug down logs up sh start
bash build build-dev debug down logs up sh start:
	@>&2 echo "\033[48;5;9;38;5;15m                     \033[49;39m"
	@>&2 echo "\033[48;5;9;38;5;15m  You're in docker!  \033[49;39m"
	@>&2 echo "\033[48;5;9;38;5;15m                     \033[49;39m"
	@>&2 echo ""
	@>&2 echo "The command \033[38;5;2mmake $@\033[39m is only intended to be run from your host"
	@>&2 echo ""
	@exit 1
else

.PHONY: start
start: build up ## Build and start the containers

.PHONY: build
build: ## Builds the Docker images
	@echo "Running\033[38;5;2m $(DOCKER_COMP) build --pull --no-cache\033[39m..."
	@echo ""
	@$(DOCKER_COMP) build --pull --no-cache

.PHONY: build-dev
build-dev: ## Build the Docker images using docker's cache layers. Useful when you're working on the Dockerfile
	@echo "Running\033[38;5;2m $(DOCKER_COMP) build\033[39m..."
	@echo ""
	@$(DOCKER_COMP) build

.PHONY: up
up: ## Start the docker hub in detached mode (no logs)
ifeq ($(CONT_IS_RUNNING), 1)
up: down
endif
	@echo "Running\033[38;5;2m $(DOCKER_COMP) up --detach --wait\033[39m..."
	@echo ""
	@$(DOCKER_COMP) up --detach --wait

.PHONY: debug
debug: ## Start the docker hub with debug in detached mode (no logs)
ifeq ($(CONT_IS_RUNNING), 1)
debug: down
endif
	@echo "Running\033[38;5;2m XDEBUG_MODE=debug $(DOCKER_COMP) up --detach --wait\033[39m..."
	@echo ""
	@XDEBUG_MODE=debug $(DOCKER_COMP) up --detach --wait
	@echo ""
	@echo "\033[48;5;2;38;5;0m                                  \033[49;39m"
	@echo "\033[48;5;2;38;5;0m  [OK] You're now in debug mode!  \033[49;39m"
	@echo "\033[48;5;2;38;5;0m                                  \033[49;39m"
	@echo ""
	@echo "You may now run your command in debug mode inside docker with the following:"
	@echo ""
	@echo "\033[38;5;2m  XDEBUG_SESSION=1 PHP_IDE_CONFIG=\"serverName=$(XDEBUG_SERVER_NAME)\" php bin/console\033[39m"
	@echo ""

.PHONY: down
down: ## Stop the docker hub
ifneq ($(CONT_IS_RUNNING), )
	@echo "Running\033[38;5;2m $(DOCKER_COMP) down --remove-orphans\033[39m..."
	@echo ""
	@$(DOCKER_COMP) down --remove-orphans
endif

.PHONY: logs
logs: -ensure-container-is-up ## Show live logs
	@echo "Running\033[38;5;2m $(DOCKER_COMP) logs --tail=0 --follow\033[39m..."
	@echo ""
	@$(DOCKER_COMP) logs --tail=0 --follow

.PHONY: sh
sh: -ensure-container-is-up ## Connect to the FrankenPHP container
	@echo "Running\033[38;5;2m $(PHP_CONT) sh\033[39m..."
	@echo ""
	@$(PHP_CONT) sh

.PHONY: bash
bash: -ensure-container-is-up ## Connect to the FrankenPHP container via bash so up and down arrows go to previous commands
	@echo "Running\033[38;5;2m $(PHP_CONT) bash\033[39m..."
	@echo ""
	@$(PHP_CONT) bash
endif

## —— Composer 🧙 ——————————————————————————————————————————————————————————————
# The pipe is used to tell Make that the prerequisite on the right should not be used to determine if the target is out of date
vendor: composer.lock | -ensure-container-is-up ## Install vendors according to the current composer.lock file
ifeq ($(IS_IN_DOCKER), 0)
	$(PHP_CONT) make $@
else
ifneq ($(wildcard ./vendor/.*),)
	@echo ""
	@echo "\033[38;5;3m  !                                                                            \033[39m"
	@echo "\033[38;5;3m  ! [NOTE] The vendor folder is outdated compared to composer.lock             \033[39m"
	@echo "\033[38;5;3m  !        Sometimes it's due to composer detecting that no changes are needed.\033[39m"
	@echo "\033[38;5;3m  !        Recreating the folder file fixes that.                              \033[39m"
	@echo "\033[38;5;3m  !                                                                            \033[39m"
	@echo ""
	@echo "Running\033[38;5;2m rm -rf vendor\033[39m..."
	@rm -rf vendor/
endif
	@echo "Running\033[38;5;2m composer install --prefer-dist --no-dev --no-progress --no-scripts --no-interaction\033[39m..."
	@echo ""
	@composer install --prefer-dist --no-dev --no-progress --no-scripts --no-interaction
endif

# The pipe is used to tell Make that the prerequisite on the right should not be used to determine if the target is out of date
composer.lock: composer.json | -ensure-container-is-up
ifeq ($(IS_IN_DOCKER), 0)
	@$(PHP_CONT) make $@
else
# Do not use composer-update as a pre-requisite or it will run this all the time
# This should be run ONLY if composer.json is more recent than composer.lock
	@make composer-update
	@touch composer.lock
endif

.PHONY: composer-update
composer-update: -ensure-container-is-up composer.json ## Update your dependencies to the latest version according to composer.json, and updates the composer.lock file
ifeq ($(IS_IN_DOCKER), 0)
	@$(PHP_CONT) make $@
else
	@echo "Running\033[38;5;2m composer update --prefer-dist --no-dev --no-interaction\033[39m..."
	@echo ""
	@composer update --prefer-dist --no-dev --no-interaction
endif

## —— Code Quality 🛠️ ——————————————————————————————————————————————————————————
.PHONY: phpstan
phpstan: -ensure-container-is-up ## finds bugs with static analysis tools
ifeq ($(IS_IN_DOCKER), 0)
	@$(PHP_CONT) make $@
else
	@echo "Running\033[38;5;2m phpstan\033[39m..."
	@echo ""
	@phpstan
endif

## —— Symfony 🎵 ———————————————————————————————————————————————————————————————
.PHONY: about
about: -ensure-container-is-up ## Display information about the current project
ifeq ($(IS_IN_DOCKER), 0)
	@$(PHP_CONT) make $@
else
	@echo "Running\033[38;5;2m php bin/console $@\033[39m..."
	@echo ""
	@php bin/console $@
endif

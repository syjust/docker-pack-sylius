PROJECT_PATH_OUTSIDE_DOCKER := $(shell grep ^PROJECT_PATH_OUTSIDE_DOCKER= ./.env | cut -d '=' -f 2-)
BACKSRC := $(PROJECT_PATH_OUTSIDE_DOCKER)

WITH_DB=$(shell grep ^WITH_DB ./.env | cut -d '=' -f 2-)

COMPOSE_FILE_PATH := -f docker-compose.yml
ifeq ($(WITH_DB), 1)
COMPOSE_FILE_PATH := $(COMPOSE_FILE_PATH) -f docker-compose-db.yml
endif

PROJECT_NAME=$(shell grep ^COMPOSE_PROJECT_NAME ./.env | cut -d '=' -f 2-)
APP_ENV=$(shell grep ^APP_ENV= ./.env | cut -d '=' -f 2-)
DOCKER_EXEC_CMD=$(DOCKER_COMPOSE) exec
.DEFAULT_GOAL := help
ARGUMENT=$(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS)) #split argument from make
EVAL := $(eval $(ARGUMENT):;@:) #split argument from make
CURRENT_UID=$(shell id -u):$(shell id -g)
export HOST_UID=$(shell id -u)
export HOST_USER=$(shell whoami)
export HOST_GROUP=$(shell getent group docker | cut -d: -f3)
DOCKER_COMPOSE=@docker-compose $(COMPOSE_FILE_PATH)

## —— ComposedCommand 🚀 ———————————————————————————————————————————————————————————————
buildProject: install ## Alias for install


checkSetup: ## Check your setup folder
ifeq (,$(wildcard ./.env)) #if no .env
		@cp .env.dist .env
		@echo 'We have just generate a .env file for you'
		@echo 'Please configure this new .env'
		@exit 1;
endif
ifeq ($(BACKSRC), ./)
		@echo 'Install a new project'
		sed -i 's/^PROJECT_PATH_OUTSIDE_DOCKER.*/PROJECT_PATH_OUTSIDE_DOCKER=.\/sylius/' .env || \
		sed -i '1 i\PROJECT_PATH_OUTSIDE_DOCKER=.\/sylius' .env
		$(DOCKER_COMPOSE) build
		$(DOCKER_COMPOSE) up -d
		@sleep 5
		$(DOCKER_EXEC_CMD) php composer create-project sylius/sylius-standard $(BACKSRC)
		$(DOCKER_COMPOSE) stop
		$(DOCKER_COMPOSE) up -d
		@sleep 5
		$(DOCKER_EXEC_CMD) php php bin/console sylius:install
		$(DOCKER_EXEC_CMD) php yarn install
		$(DOCKER_EXEC_CMD) php yarn build
		$(DOCKER_EXEC_CMD) php chmod -R 777 /var/www
		@exit 1;
endif


install: checkSetup destroy buildImage start ## Check config files, destroy, rebuild, start containers, and do afterbuild

deploy: yarnBuild cacheClear restart ## update preproduction/production env

## —— Docker 🐳 ———————————————————————————————————————————————————————————————

start: ## Start the containers (only work when installed)
	   $(DOCKER_COMPOSE) up -d $(ARGUMENT)

restart: ## Restart the containers (only work when started)
		 $(DOCKER_COMPOSE) restart $(ARGUMENT)

stop: ## Stop the containers (only work when started)
		$(DOCKER_COMPOSE) stop $(ARGUMENT)

destroy: ## Destroy the containers
		$(DOCKER_COMPOSE) stop $(ARGUMENT)
		$(DOCKER_COMPOSE) rm -f $(ARGUMENT)

buildImage: ## Build the containers
		@echo $(DOCKER_COMPOSE)
		$(DOCKER_COMPOSE) build $(ARGUMENT)

## —— Vendors 🧙‍️ ———————————————————————————————————————————————————————————————

vendorInstall: ## Remove and reinstall the vendors
		$(DOCKER_EXEC_CMD) php rm -rf vendor
		$(DOCKER_EXEC_CMD) php composer install

vendorUpdate: ## Remove and update the vendors
		$(DOCKER_EXEC_CMD) php rm -rf vendor
		$(DOCKER_EXEC_CMD) php composer update

cacheClear: ## Clear symfony cache
		$(DOCKER_EXEC_CMD) php php bin/console c:c


## —— Front 🎨 ———————————————————————————————————————————————————————————————

yarnInstall: ## Reinstall node_modules
		$(DOCKER_EXEC_CMD) php yarn install

yarnAdd: ## Add a package (node_modules) to assets
		$(DOCKER_EXEC_CMD) php yarn add --dev $(ARGUMENT)

yarnBuild: ## build assets
		$(DOCKER_EXEC_CMD) php yarn build

watchAssets: ## Watch assets
		$(DOCKER_EXEC_CMD) php yarn watch

reloadAssets: yarnInstall yarnBuild ## Rebuild assets

## —— Database 🏢 ———————————————————————————————————————————————————————————————

syliusInstall:  ## Install sylius with demo data
		$(DOCKER_EXEC_CMD) php php bin/console sylius:install

## —— Usefull 🧐 ———————————————————————————————————————————————————————————————

bash: ## Open a bash inside a container
ifneq ($(strip $(ARGUMENT)),)
		$(DOCKER_EXEC_CMD) $(ARGUMENT) /bin/bash
else
		@echo Usage: make bash {container}
		@exit 1
endif

help: ## Outputs this help screen
		@grep -E '(^[a-zA-Z0-9_-]+:.*?##.*$$)|(^##)' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}{printf "\033[32m%-30s\033[0m %s\n", $$1, $$2}' | sed -e 's/\[32m##/[33m/'
		@echo ""
		@echo "Make sure you are in the docker groups, give the repo's right to this group (read and write)"
		@echo ""

SHELL := /bin/bash
VIRTUALENV_ROOT := $(shell [ -z $$VIRTUAL_ENV ] && echo $$(pwd)/venv || echo $$VIRTUAL_ENV)
DM_ENVIRONMENT ?= development

ifeq ($(DM_ENVIRONMENT),development)
	GULP_ENVIRONMENT := development
else
	GULP_ENVIRONMENT := production
endif

.PHONY: run-all
run-all: requirements yarn-install frontend-build run-app

.PHONY: run-app
run-app: show-environment virtualenv
	${VIRTUALENV_ROOT}/bin/python application.py runserver

.PHONY: virtualenv
virtualenv:
	[ -z $$VIRTUAL_ENV ] && [ ! -d venv ] && virtualenv -p python3 venv || true

.PHONY: upgrade-pip
upgrade-pip: virtualenv
	${VIRTUALENV_ROOT}/bin/pip install --upgrade pip

.PHONY: requirements
requirements: virtualenv test-requirements upgrade-pip requirements.txt
	${VIRTUALENV_ROOT}/bin/pip install -r requirements.txt

.PHONY: requirements-dev
requirements-dev: virtualenv test-requirements requirements-dev.txt
	${VIRTUALENV_ROOT}/bin/pip install -r requirements-dev.txt

.PHONY: freeze-requirements
freeze-requirements:
	rm -rf venv-freeze
	virtualenv -p python3 venv-freeze
	$$(pwd)/venv-freeze/bin/pip install -r requirements-app.txt
	echo '# This file is autogenerated. Do not edit it manually.' > requirements.txt
	cat requirements-app.txt >> requirements.txt
	echo '' >> requirements.txt
	$$(pwd)/venv-freeze/bin/pip freeze -r requirements-app.txt | sed -n '/The following requirements were added by pip freeze/,$$p' >> requirements.txt
	rm -rf venv-freeze

.PHONY: yarn-install
yarn-install:
	yarn

.PHONY: frontend-build
frontend-build:
	yarn run --silent frontend-build:${GULP_ENVIRONMENT}

.PHONY: test
test: show-environment test-requirements frontend-build test-flake8 test-python

.PHONY: test-requirements
test-requirements:
	@diff requirements-app.txt requirements.txt | grep '<' \
	    && { echo "requirements.txt doesn't match requirements-app.txt."; \
	         echo "Run 'make freeze-requirements' to update."; exit 1; } \
	    || { echo "requirements.txt is up to date"; exit 0; }

.PHONY: test-flake8
test-flake8: virtualenv
	${VIRTUALENV_ROOT}/bin/flake8 .

.PHONY: test-python
test-python: virtualenv
	${VIRTUALENV_ROOT}/bin/py.test ${PYTEST_ARGS}

.PHONY: show-environment
show-environment:
	@echo "Environment variables in use:"
	@env | grep DM_ || true

.PHONY: docker-build
docker-build:
	$(if ${RELEASE_NAME},,$(eval export RELEASE_NAME=$(shell git describe)))
	@echo "Building a docker image for ${RELEASE_NAME}..."
	docker build -t digitalmarketplace/admin-frontend --build-arg release_name=${RELEASE_NAME} .
	docker tag digitalmarketplace/admin-frontend digitalmarketplace/admin-frontend:${RELEASE_NAME}

.PHONY: docker-push
docker-push:
	$(if ${RELEASE_NAME},,$(eval export RELEASE_NAME=$(shell git describe)))
	docker push digitalmarketplace/admin-frontend:${RELEASE_NAME}

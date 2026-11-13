# quench-common: the library every QuenchWorks chart depends on.
#   make lint     helm lint the library
#   make test     render real consumer charts against this tree (CHARTS=../charts, CONSUMERS=dex vault ...)
#   make package  build the chart tgz into dist/

SHELL := /bin/bash
.SHELLFLAGS := -euo pipefail -c
.DEFAULT_GOAL := help
MAKEFLAGS += --no-print-directory

CHARTS    ?= ../charts
CONSUMERS ?=

.PHONY: help lint test package

help: ## list targets
	@grep -hE '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  make %-8s %s\n", $$1, $$2}'

lint: ## helm lint the library
	helm lint quench-common

test: lint ## render consumer charts against this tree
	scripts/render-consumers.sh $(CHARTS) $(CONSUMERS)

package: test ## build the chart tgz into dist/
	helm package quench-common -d dist

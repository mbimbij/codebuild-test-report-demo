SHELL := /bin/bash
ifndef APPLICATION_NAME
$(error APPLICATION_NAME is not set)
endif
include infra.env
PIPELINE_STACK_NAME=$(APPLICATION_NAME)-pipeline

all:
	- $(MAKE) pipeline
pipeline:
	./create-pipeline.sh $(APPLICATION_NAME) $(PIPELINE_STACK_NAME) $(GITHUB_REPO) $(GITHUB_REPO_BRANCH)

delete-all:
	- $(MAKE) delete-pipeline
delete-pipeline:
	./delete-stack-wait-termination.sh $(PIPELINE_STACK_NAME)

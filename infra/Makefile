SHELL := /bin/bash
ifndef APPLICATION_NAME
$(error APPLICATION_NAME is not set)
endif
include infra.env
PIPELINE_STACK_NAME=$(APPLICATION_NAME)-pipeline
EXECUTION_ENVIRONMENT_STACK_NAME=$(APPLICATION_NAME)-execution-environment

all:
	- $(MAKE) pipeline
	- $(MAKE) ami
	- $(MAKE) execution-environment
pipeline:
	./create-pipeline.sh $(APPLICATION_NAME) $(PIPELINE_STACK_NAME) $(GITHUB_REPO) $(GITHUB_REPO_BRANCH)
ami:
	$(eval BASE_AMI_ID := $(shell aws ssm get-parameters --names /aws/service/canonical/ubuntu/server/20.04/stable/current/amd64/hvm/ebs-gp2/ami-id --query 'Parameters[0].[Value]' --output text))
	$(eval AWS_REGION := $(shell aws configure get region))
	./create-ami.sh $(APPLICATION_NAME) $(BASE_AMI_ID) $(AWS_REGION)
ssh-key-pair:
	./create-ssh-key-pair.sh $(SSH_KEY_NAME) $(SSH_KEY_PATH)
execution-environment: ssh-key-pair
	$(eval AMI_ID := $(shell aws ec2 describe-images --owners self --query "Images[?Name=='$(APPLICATION_NAME)'].ImageId" --output text))
	./create-execution-environment.sh $(APPLICATION_NAME) $(EXECUTION_ENVIRONMENT_STACK_NAME) $(AMI_ID) $(SSH_KEY_NAME)


delete-all:
	- $(MAKE) delete-pipeline
delete-pipeline:
	./delete-stack-wait-termination.sh $(PIPELINE_STACK_NAME)
delete-ami:
	$(eval AMI_ID := $(shell aws ec2 describe-images --owners self --query "Images[?Name=='$(APPLICATION_NAME)'].ImageId" --output text))
	aws ec2 deregister-image --image-id $(AMI_ID)
delete-ssh-key-pair:
	aws ec2 delete-key-pair --key-name $(SSH_KEY_NAME)
delete-execution-environment: delete-ssh-key-pair
	./delete-stack-wait-termination.sh $(EXECUTION_ENVIRONMENT_STACK_NAME)

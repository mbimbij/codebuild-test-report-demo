SHELL := /bin/bash
ifndef APPLICATION_NAME
$(error APPLICATION_NAME is not set)
endif
include infra.env
PIPELINE_STACK_NAME=$(APPLICATION_NAME)-pipeline
STAGING_ENVIRONMENT_STACK_NAME=$(APPLICATION_NAME)-staging-instance
PRODUCTION_ENVIRONMENT_STACK_NAME=$(APPLICATION_NAME)-production-instance
NETWORK_STAGING_STACK_NAME=network-staging
NETWORK_PRODUCTION_STACK_NAME=network-staging
AWS_REGION := $(shell aws configure get region)

.PHONY: network

all:
	- $(MAKE) ami
	- $(MAKE) network
	- $(MAKE) staging-instance
	- $(MAKE) production-instance
	- $(MAKE) pipeline
pipeline:
	$(eval STAGING_ENVIRONMENT_DNS := $(shell aws cloudformation list-exports --region $(AWS_REGION) --query "Exports[?Name=='$(STAGING_ENVIRONMENT_STACK_NAME)::InstancePrivateDns'].Value" --output text))
	./create-pipeline.sh $(APPLICATION_NAME) $(PIPELINE_STACK_NAME) $(GITHUB_REPO) $(GITHUB_REPO_BRANCH) $(NETWORK_STAGING_STACK_NAME) $(STAGING_ENVIRONMENT_DNS)
ami:
	$(eval BASE_AMI_ID := $(shell aws ssm get-parameters --names /aws/service/canonical/ubuntu/server/20.04/stable/current/amd64/hvm/ebs-gp2/ami-id --query 'Parameters[0].[Value]' --output text))
	cd ami && ./create-ami.sh $(APPLICATION_NAME) $(BASE_AMI_ID) $(AWS_REGION)
ssh-key-pair:
	./create-ssh-key-pair.sh $(SSH_KEY_NAME) $(SSH_KEY_PATH)
staging-instance: ssh-key-pair
	- $(MAKE) ami
	$(eval AMI_ID := $(shell aws ec2 describe-images --owners self --query "Images[?Name=='$(APPLICATION_NAME)'].ImageId" --output text))
	./create-instance.sh $(APPLICATION_NAME) $(STAGING_ENVIRONMENT_STACK_NAME) $(AMI_ID) $(SSH_KEY_NAME) staging $(NETWORK_STAGING_STACK_NAME) PrivateSubnetA
production-instance: ssh-key-pair
	- $(MAKE) ami
	$(eval AMI_ID := $(shell aws ec2 describe-images --owners self --query "Images[?Name=='$(APPLICATION_NAME)'].ImageId" --output text))
	./create-instance.sh $(APPLICATION_NAME) $(PRODUCTION_ENVIRONMENT_STACK_NAME) $(AMI_ID) $(SSH_KEY_NAME) production $(NETWORK_STAGING_STACK_NAME) PrivateSubnetB
network-staging: ssh-key-pair
	aws cloudformation deploy --stack-name $(NETWORK_STAGING_STACK_NAME) --template-file network/network-cfn.yml --parameter-overrides file://network/network-staging.json
network-production: ssh-key-pair
	aws cloudformation deploy --stack-name $(NETWORK_PRODUCTION_STACK_NAME) --template-file network/network-cfn.yml --parameter-overrides file://network/network-production.json


delete-all:
	- $(MAKE) delete-pipeline
	- $(MAKE) delete-staging-instance
	- $(MAKE) delete-network-staging
	- $(MAKE) delete-production-instance
	- $(MAKE) delete-network-production
	- $(MAKE) delete-ami
delete-light: delete-staging-instance delete-production-instance delete-pipeline delete-network
delete-pipeline:
	./delete-stack-wait-termination.sh $(PIPELINE_STACK_NAME)
delete-ami:
	$(eval AMI_ID := $(shell aws ec2 describe-images --owners self --query "Images[?Name=='$(APPLICATION_NAME)'].ImageId" --output text))
	aws ec2 deregister-image --image-id $(AMI_ID)
delete-ssh-key-pair:
	aws ec2 delete-key-pair --key-name $(SSH_KEY_NAME)
delete-staging-instance: delete-ssh-key-pair
	./delete-stack-wait-termination.sh $(STAGING_ENVIRONMENT_STACK_NAME)
delete-production-instance: delete-ssh-key-pair
	./delete-stack-wait-termination.sh $(PRODUCTION_ENVIRONMENT_STACK_NAME)
delete-network-staging:
	./delete-stack-wait-termination.sh $(NETWORK_STAGING_STACK_NAME)
delete-network-production:
	./delete-stack-wait-termination.sh $(NETWORK_PRODUCTION_STACK_NAME)

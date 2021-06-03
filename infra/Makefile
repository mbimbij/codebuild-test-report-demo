SHELL := /bin/bash
ifndef APPLICATION_NAME
$(error APPLICATION_NAME is not set)
endif
include infra.env
PIPELINE_STACK_NAME=$(APPLICATION_NAME)-pipeline
STAGING_INSTANCE_STACK_NAME=$(APPLICATION_NAME)-instance-staging
PRODUCTION_INSTANCE_STACK_NAME=$(APPLICATION_NAME)-instance-production
NETWORK_STAGING_STACK_NAME=$(APPLICATION_NAME)-network-staging
NETWORK_PRODUCTION_STACK_NAME=$(APPLICATION_NAME)-network-production
AWS_REGION := $(shell aws configure get region)

.PHONY: pipeline ami ssh-key-pair

.IGNORE: ami

all:
	$(MAKE) -j3 ami network-staging network-production
	$(MAKE) -j2 instance-staging instance-production
	$(MAKE) pipeline
pipeline:
	$(eval STAGING_ENVIRONMENT_DNS := $(shell aws cloudformation list-exports --region $(AWS_REGION) --query "Exports[?Name=='$(STAGING_INSTANCE_STACK_NAME)::InstancePrivateDns'].Value" --output text))
	aws cloudformation deploy    \
      --stack-name $(PIPELINE_STACK_NAME)   \
      --template-file pipeline/pipeline-cfn.yml    \
      --capabilities CAPABILITY_NAMED_IAM   \
      --parameter-overrides     \
        ApplicationName=$(APPLICATION_NAME)   \
        GithubRepo=$(GITHUB_REPO)   \
        GithubRepoBranch=$(GITHUB_REPO_BRANCH) \
        NetworkStagingStackName=$(NETWORK_STAGING_STACK_NAME) \
        StagingEnvironmentDns=$(STAGING_ENVIRONMENT_DNS)
ami:
	$(eval BASE_AMI_ID := $(shell aws ssm get-parameters --names /aws/service/canonical/ubuntu/server/20.04/stable/current/amd64/hvm/ebs-gp2/ami-id --query 'Parameters[0].[Value]' --output text))
	cd ami && ./create-ami.sh $(APPLICATION_NAME) $(BASE_AMI_ID) $(AWS_REGION)
ssh-key-pair:
	./ssh-key-pair/create-ssh-key-pair.sh $(SSH_KEY_NAME) $(SSH_KEY_PATH)
instance-staging: ssh-key-pair
	./instances/create-instance.sh $(APPLICATION_NAME) staging $(STAGING_INSTANCE_STACK_NAME) $(NETWORK_STAGING_STACK_NAME)
instance-production: ssh-key-pair
	./instances/create-instance.sh $(APPLICATION_NAME) production $(PRODUCTION_INSTANCE_STACK_NAME) $(NETWORK_PRODUCTION_STACK_NAME)
networks:
	$(MAKE) -j2 network-staging network-production
network-staging: ssh-key-pair
	aws cloudformation deploy --stack-name $(NETWORK_STAGING_STACK_NAME) --template-file network/network-cfn.yml --parameter-overrides file://network/network-staging.json
network-production: ssh-key-pair
	aws cloudformation deploy --stack-name $(NETWORK_PRODUCTION_STACK_NAME) --template-file network/network-cfn.yml --parameter-overrides file://network/network-production.json


delete-all:
	- $(MAKE) -j2 delete-pipeline delete-ami
	- $(MAKE) -j2 delete-instance-staging delete-instance-production
	- $(MAKE) -j2 delete-network-staging delete-network-production
delete-all-except-ami:
	- $(MAKE) delete-pipeline
	- $(MAKE) -j2 delete-instance-staging delete-instance-production
	- $(MAKE) -j2 delete-network-staging delete-network-production
delete-pipeline:
	./delete-stack-wait-termination.sh $(PIPELINE_STACK_NAME)
delete-ami:
	$(eval AMI_ID := $(shell aws ec2 describe-images --owners self --query "Images[?Name=='$(APPLICATION_NAME)'].ImageId" --output text))
	aws ec2 deregister-image --image-id $(AMI_ID)
delete-ssh-key-pair:
	aws ec2 delete-key-pair --key-name $(SSH_KEY_NAME)
delete-instance-staging: delete-ssh-key-pair
	./delete-stack-wait-termination.sh $(STAGING_INSTANCE_STACK_NAME)
delete-instance-production: delete-ssh-key-pair
	./delete-stack-wait-termination.sh $(PRODUCTION_INSTANCE_STACK_NAME)
delete-network-staging:
	./delete-stack-wait-termination.sh $(NETWORK_STAGING_STACK_NAME)
delete-network-production:
	./delete-stack-wait-termination.sh $(NETWORK_PRODUCTION_STACK_NAME)

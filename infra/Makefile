SHELL := /bin/bash
ifndef APPLICATION_NAME
$(error APPLICATION_NAME is not set)
endif
include infra.env
PIPELINE_STACK_NAME=$(APPLICATION_NAME)-pipeline
INSTANCE_STAGING_STACK_NAME=$(APPLICATION_NAME)-instance-staging
INSTANCE_PRODUCTION_STACK_NAME=$(APPLICATION_NAME)-instance-production
NETWORK_STAGING_STACK_NAME=$(APPLICATION_NAME)-network-staging
NETWORK_PRODUCTION_STACK_NAME=$(APPLICATION_NAME)-network-production
AWS_REGION := $(shell aws configure get region)
AWS_ACCOUNT_ID := $(shell aws sts get-caller-identity --query "Account" --output text)
S3_BUCKET_NAME=$(AWS_REGION)-$(AWS_ACCOUNT_ID)-$(APPLICATION_NAME)-bucket
S3_BUCKET_STACK_NAME=$(APPLICATION_NAME)-bucket

.PHONY: pipeline ami ssh-key-pair s3-bucket

.IGNORE: ami

all:
	$(MAKE) s3-bucket
	$(MAKE) -j3 ami network-staging network-production
	$(MAKE) -j2 instance-staging instance-production
	$(MAKE) pipeline
s3-bucket:
	aws cloudformation deploy    \
          --stack-name $(S3_BUCKET_STACK_NAME)   \
          --template-file s3-bucket/s3-bucket.yml   \
          --parameter-overrides     \
            BucketName=$(S3_BUCKET_NAME)
pipeline: s3-bucket
	aws cloudformation package --template-file pipeline/pipeline-cfn.yml --output-template pipeline/pipeline-cfn-packaged.yml --s3-bucket $(S3_BUCKET_NAME)
	$(eval STAGING_ENVIRONMENT_DNS := $(shell aws cloudformation list-exports --region $(AWS_REGION) --query "Exports[?Name=='$(INSTANCE_STAGING_STACK_NAME)::InstancePrivateDns'].Value" --output text))
	$(eval PRODUCTION_ENVIRONMENT_DNS := $(shell aws cloudformation list-exports --region $(AWS_REGION) --query "Exports[?Name=='$(INSTANCE_PRODUCTION_STACK_NAME)::InstancePrivateDns'].Value" --output text))
	aws cloudformation deploy    \
      --stack-name $(PIPELINE_STACK_NAME)   \
      --template-file pipeline/pipeline-cfn-packaged.yml    \
      --capabilities CAPABILITY_NAMED_IAM   \
      --parameter-overrides     \
        ApplicationName=$(APPLICATION_NAME)   \
        S3Bucket=$(S3_BUCKET_NAME) \
        GithubRepo=$(GITHUB_REPO)   \
        GithubRepoBranch=$(GITHUB_REPO_BRANCH) \
        NetworkStagingStackName=$(NETWORK_STAGING_STACK_NAME) \
        NetworkProductionStackName=$(NETWORK_PRODUCTION_STACK_NAME) \
        StagingEnvironmentDns=$(STAGING_ENVIRONMENT_DNS) \
        ProductionEnvironmentDns=$(PRODUCTION_ENVIRONMENT_DNS)
ami:
	$(eval BASE_AMI_ID := $(shell aws ssm get-parameters --names /aws/service/canonical/ubuntu/server/20.04/stable/current/amd64/hvm/ebs-gp2/ami-id --query 'Parameters[0].[Value]' --output text))
	cd ami && ./create-ami.sh $(APPLICATION_NAME) $(BASE_AMI_ID) $(AWS_REGION)
ssh-key-pair:
	./ssh-key-pair/create-ssh-key-pair.sh $(SSH_KEY_NAME) $(SSH_KEY_PATH)
instance-staging: ssh-key-pair
	./instances/create-instance.sh $(APPLICATION_NAME) staging $(INSTANCE_STAGING_STACK_NAME) $(NETWORK_STAGING_STACK_NAME)
	rm instances/instance-staging-processed.json || echo ""
instance-production: ssh-key-pair
	./instances/create-instance.sh $(APPLICATION_NAME) production $(INSTANCE_PRODUCTION_STACK_NAME) $(NETWORK_PRODUCTION_STACK_NAME)
	rm instances/instance-production-processed.json || echo ""
networks:
	$(MAKE) -j2 network-staging network-production
network-staging: ssh-key-pair
	aws cloudformation deploy --stack-name $(NETWORK_STAGING_STACK_NAME) --template-file network/network-cfn.yml --parameter-overrides file://network/network-staging.json
network-production: ssh-key-pair
	aws cloudformation deploy --stack-name $(NETWORK_PRODUCTION_STACK_NAME) --template-file network/network-cfn.yml --parameter-overrides file://network/network-production.json


delete-all:
	- $(MAKE) -j2 delete-pipeline delete-ami
	- $(MAKE) delete-s3-bucket
	- $(MAKE) -j2 delete-instance-staging delete-instance-production
	- $(MAKE) -j2 delete-network-staging delete-network-production
delete-s3-bucket:
	./stack-deletion/delete-stack-wait-termination.sh $(S3_BUCKET_STACK_NAME)
delete-all-except-ami:
	- $(MAKE) delete-pipeline
	- $(MAKE) -j2 delete-instance-staging delete-instance-production
	- $(MAKE) -j2 delete-network-staging delete-network-production
delete-pipeline:
	./stack-deletion/delete-stack-wait-termination.sh $(PIPELINE_STACK_NAME)
delete-ami:
	$(eval AMI_ID := $(shell aws ec2 describe-images --owners self --query "Images[?Name=='$(APPLICATION_NAME)'].ImageId" --output text))
	aws ec2 deregister-image --image-id $(AMI_ID)
delete-ssh-key-pair:
	aws ec2 delete-key-pair --key-name $(SSH_KEY_NAME)
delete-instance-staging: delete-ssh-key-pair
	./stack-deletion/delete-stack-wait-termination.sh $(INSTANCE_STAGING_STACK_NAME)
delete-instance-production: delete-ssh-key-pair
	./stack-deletion/delete-stack-wait-termination.sh $(INSTANCE_PRODUCTION_STACK_NAME)
delete-network-staging:
	./stack-deletion/delete-stack-wait-termination.sh $(NETWORK_STAGING_STACK_NAME)
delete-network-production:
	./stack-deletion/delete-stack-wait-termination.sh $(NETWORK_PRODUCTION_STACK_NAME)

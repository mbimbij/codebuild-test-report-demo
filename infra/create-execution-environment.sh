#!/bin/bash

if [[ "$#" -ne 4 ]]; then
  echo -e "usage:\n./create-execution-environment.sh \$APPLICATION_NAME \$STACK_NAME \$AMI_ID \$KEY_NAME"
  exit 1
fi

# TODO: verify the presence of the SSH key in the AWS account and fail if absent

APPLICATION_NAME=$1
STACK_NAME=$2
AMI_ID=$3
KEY_NAME=$4

echo -e "##############################################################################"
echo -e "creating execution-environment"
echo -e "##############################################################################"
aws cloudformation deploy \
  --stack-name $STACK_NAME \
  --template-file execution-environment-cfn.yml \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    KeyName=$KEY_NAME \
    AmiId=$AMI_ID \
    ApplicationName=$APPLICATION_NAME

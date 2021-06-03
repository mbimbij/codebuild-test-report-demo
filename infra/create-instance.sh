#!/bin/bash

if [[ "$#" -ne 7 ]]; then
  echo -e "usage:\n./create-execution-environment.sh \$APPLICATION_NAME \$STACK_NAME \$AMI_ID \$KEY_NAME \$ENVIRONMENT \$NETWORK_STACK_NAME \$SUBNET_NAME"
  exit 1
fi

APPLICATION_NAME=$1
STACK_NAME=$2
AMI_ID=$3
KEY_NAME=$4
ENVIRONMENT=$5
NETWORK_STACK_NAME=$6
SUBNET_NAME=$7

echo -e "##############################################################################"
echo -e "creating environment \"$ENVIRONMENT\""
echo -e "##############################################################################"
aws cloudformation deploy \
  --stack-name $STACK_NAME \
  --template-file instance-cfn.yml \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    KeyName=$KEY_NAME \
    AmiId=$AMI_ID \
    ApplicationName=$APPLICATION_NAME \
    Environment=$ENVIRONMENT \
    NetworkStackName=$NETWORK_STACK_NAME \
    SubnetName=$SUBNET_NAME

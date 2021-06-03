#!/bin/bash

if [[ "$#" -ne 4 ]]; then
  echo -e "usage:\n./create-instance.sh \$APPLICATION_NAME \$ENVIRONMENT \$STACK_NAME \$NETWORK_STACK_NAME"
  exit 1
fi

APPLICATION_NAME=$1
ENVIRONMENT=$2
STACK_NAME=$3
NETWORK_STACK_NAME=$4

echo "APPLICATION_NAME: $APPLICATION_NAME "
echo "ENVIRONMENT: $ENVIRONMENT "
echo "STACK_NAME: $STACK_NAME "
echo "NETWORK_STACK_NAME: $NETWORK_STACK_NAME "

echo -e "##############################################################################"
echo -e "creating instances for environment \"$ENVIRONMENT\""
echo -e "##############################################################################"
AMI_ID=$(aws ec2 describe-images --owners self --query "Images[?Name=='$APPLICATION_NAME'].ImageId" --output text)
jq ". + [{\"ParameterKey\": \"ApplicationName\", \"ParameterValue\": \"$APPLICATION_NAME\"},{\"ParameterKey\": \"AmiId\", \"ParameterValue\": \"$AMI_ID\"},{\"ParameterKey\": \"NetworkStackName\", \"ParameterValue\": \"$NETWORK_STACK_NAME\"}]" \
  instances/instance-$ENVIRONMENT.json > instances/instance-$ENVIRONMENT-processed.json
aws cloudformation deploy --stack-name $STACK_NAME \
  --capabilities CAPABILITY_NAMED_IAM \
  --template-file instances/instance-cfn.yml \
  --parameter-overrides file://instances/instance-$ENVIRONMENT-processed.json
#!/bin/bash

if [ -z $1 ]; then
  echo -e "usage:\n./create-all.sh \$APPLICATION_NAME"
  exit 1
fi

source infra/infra.env

export APPLICATION_NAME=$1
export PIPELINE_STACK_NAME=$APPLICATION_NAME-pipeline

echo -e "##############################################################################"
echo -e "creating ci/cd pipeline stack"
echo -e "##############################################################################"
aws cloudformation deploy    \
  --stack-name $PIPELINE_STACK_NAME   \
  --template-file infra/pipeline-cfn.yml    \
  --capabilities CAPABILITY_NAMED_IAM   \
  --parameter-overrides     \
    ApplicationName=$APPLICATION_NAME
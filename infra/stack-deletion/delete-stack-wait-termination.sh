#!/bin/bash

if [[ -z $1 ]]; then
  echo -e "usage:\n./delete-stack-wait-termination.sh \$STACK_NAME"
  exit 1
fi

STACK_NAME=$1

echo -e "##############################################################################"
echo -e "deleting stack $STACK_NAME"
echo -e "##############################################################################"

S3_BUCKETS=$(aws cloudformation describe-stack-resources --stack-name $STACK_NAME --query "StackResources[?ResourceType=='AWS::S3::Bucket'].PhysicalResourceId" --output text)
for S3_BUCKET in $S3_BUCKETS
do
  echo -e "## force deleting S3 bucket $S3_BUCKET for stack $STACK_NAME"
  aws s3 rb s3://$S3_BUCKET --force
done

aws cloudformation delete-stack --stack-name $STACK_NAME
aws cloudformation wait stack-delete-complete --stack-name $STACK_NAME
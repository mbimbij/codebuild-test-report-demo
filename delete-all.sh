#!/bin/bash

if [ -z $1 ]; then
  echo -e "usage:\n./delete-all.sh \$APPLICATION_NAME"
  exit 1
fi

source infra/infra.env

export APPLICATION_NAME=$1
export PIPELINE_STACK_NAME=$APPLICATION_NAME-pipeline

export S3_BUCKET_NAME="$AWS_REGION-$ACCOUNT_ID-$APPLICATION_NAME-bucket-pipeline"

echo -e "##############################################################################"
echo -e "emptying S3 bucket: $S3_BUCKET_NAME"
echo -e "##############################################################################"

aws s3 rm s3://$S3_BUCKET_NAME --recursive

echo -e "##############################################################################"
echo -e "deleting ci/cd pipeline stack"
echo -e "##############################################################################"
aws cloudformation delete-stack --stack-name $PIPELINE_STACK_NAME
aws cloudformation wait stack-delete-complete --stack-name $PIPELINE_STACK_NAME
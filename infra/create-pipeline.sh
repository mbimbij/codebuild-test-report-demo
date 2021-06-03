#!/bin/bash

if [[ "$#" -ne 6 ]]; then
  echo -e "usage:\n./create-all.sh \$APPLICATION_NAME \$PIPELINE_STACK_NAME \$GITHUB_REPO \$GITHUB_REPO_BRANCH \$STAGING_ENVIRONMENT_DNS"
  exit 1
fi

APPLICATION_NAME=$1
PIPELINE_STACK_NAME=$2
GITHUB_REPO=$3
GITHUB_REPO_BRANCH=$4
NETWORK_STACK_NAME=$5
STAGING_ENVIRONMENT_DNS=$6

echo -e "##############################################################################"
echo -e "creating ci/cd pipeline stack"
echo -e "##############################################################################"
aws cloudformation deploy    \
  --stack-name $PIPELINE_STACK_NAME   \
  --template-file pipeline-cfn.yml    \
  --capabilities CAPABILITY_NAMED_IAM   \
  --parameter-overrides     \
    ApplicationName=$APPLICATION_NAME   \
    GithubRepo=$GITHUB_REPO   \
    GithubRepoBranch=$GITHUB_REPO_BRANCH \
    NetworkStackName=$NETWORK_STACK_NAME \
    StagingEnvironmentDns=$STAGING_ENVIRONMENT_DNS
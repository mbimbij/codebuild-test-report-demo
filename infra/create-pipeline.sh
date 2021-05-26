#!/bin/bash

if [[ "$#" -ne 4 ]]; then
  echo -e "usage:\n./create-all.sh \$APPLICATION_NAME \$PIPELINE_STACK_NAME \$GITHUB_REPO \$GITHUB_REPO_BRANCH"
  exit 1
fi

export APPLICATION_NAME=$1
export PIPELINE_STACK_NAME=$2

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
    GithubRepoBranch=$GITHUB_REPO_BRANCH
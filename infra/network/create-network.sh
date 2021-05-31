#!/bin/bash

if [[ -z $1 ]]; then
  echo -e "usage:\n./create-network.sh \$STACK_NAME"
  exit 1
fi
STACK_NAME=$1

aws cloudformation deploy \
		--stack-name $STACK_NAME-network \
		--template-file network-cfn.yml
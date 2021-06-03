#!/bin/bash

if [[ "$#" -ne 3 ]]; then
  echo -e "usage:\n./create-ami.sh \$APPLICATION_NAME \$BASE_AMI_ID \$AWS_REGION"
  exit 1
fi

APPLICATION_NAME=$1
BASE_AMI_ID=$2
AWS_REGION=$3

set -e
cd packer-ami
packer build \
  -var "ami_name=$APPLICATION_NAME" \
  -var "ami_id=$BASE_AMI_ID" \
  -var "region=$AWS_REGION" \
  ubuntu-springboot-ready.json

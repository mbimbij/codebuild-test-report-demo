#!/bin/bash

key_pair_exists_by_name(){
  aws ec2 describe-key-pairs --key-names $1
  [[ $? == 0 ]]
}

key_changed(){
  SSH_KEY_NAME=$1
  SSH_KEY_PATH=$2
  aws_key_fingerprint=$(aws ec2 describe-key-pairs --key-names $SSH_KEY_NAME --query "KeyPairs[].KeyFingerprint" --output text)
  local_key_fingerprint=$(ssh-keygen -ef $SSH_KEY_PATH -m PEM | openssl rsa -RSAPublicKey_in -outform DER | openssl md5 -c | sed 's/(stdin)= //')
  echo "aws_key_fingerprint $aws_key_fingerprint" >&2
  echo "local_key_fingerprint $local_key_fingerprint" >&2
  [[ "$aws_key_fingerprint" != "$local_key_fingerprint" ]]
}

if [[ "$#" -ne 2 ]]; then
  echo -e "usage:\n./create-all.sh \$SSH_KEY_NAME \$SSH_KEY_PATH"
  exit 1
fi

export SSH_KEY_NAME=$1
export SSH_KEY_PATH=$2

echo -e "##############################################################################"
echo -e "creating ssh key pair \"$SSH_KEY_NAME\" from $SSH_KEY_PATH if it does not exist or if has changed"
echo -e "##############################################################################"
if (! key_pair_exists_by_name $SSH_KEY_NAME) || key_changed $SSH_KEY_NAME $SSH_KEY_PATH ; then
  echo "Creating or updating key $SSH_KEY_NAME."
  PUBLIC_KEY_BASE_64=$(cat $SSH_KEY_PATH | base64)
  aws ec2 delete-key-pair --key-name $SSH_KEY_NAME
  aws ec2 import-key-pair --key-name $SSH_KEY_NAME --public-key-material "$PUBLIC_KEY_BASE_64"
else
  echo "key $SSH_KEY_NAME already exists and hasn't changed. Not doing anything"
fi

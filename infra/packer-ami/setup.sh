#! /bin/bash

sleep 30

sudo apt update

# installing some utilities
sudo apt install -y tree ncdu mlocate tmux jq

# installing java
sudo apt install openjdk-16-jdk -y

AWS_REGION=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | jq .region -r)
if [[ -z $AWS_REGION ]]; then
  echo "AWS_REGION is empty, defaulting to 'us-east-1'"
  AWS_REGION="us-east-1"
fi
echo "region is: $AWS_REGION"

# installing codedeploy agent
sudo apt-get install ruby wget -y
wget https://aws-codedeploy-$AWS_REGION.s3.$AWS_REGION.amazonaws.com/latest/install
chmod +x ./install
sudo ./install auto | tee /tmp/logfile
sudo systemctl start codedeploy-agent
sudo systemctl enable codedeploy-agent

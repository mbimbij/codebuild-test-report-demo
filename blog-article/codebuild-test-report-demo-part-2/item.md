
---
title: Pipeline CI/CD d'une application Java dans EC2 - partie 2
date: 10:00 05/26/2021
author: Joseph M'Bimbi-Bene
hero_classes: 'text-light overlay-dark-gradient'
hero_image: article-logo.png
taxonomy:
category: blog
tag: [devops, cloud, tests]
---

Dans cette article, nous allons enrichir notre pipeline et déployer l'application dans une instance EC2.

===


### Sommaire

- [Introduction](#introduction)
  * [Rappel de la cible](#cible)
  * [Rappel des étapes](#etapes)
  * [Plan de l'article](#plan-article)
- [Implémentation avec `CloudFormation`](#implementation-cloudformation)
  * [0. Refacto - Introduction d'un `Makefile` pour la création et la destruction des éléments d'infra](#2.0-refacto-intro-makefile-infra)
  * [1. Création d'une AMI (image EC2) prête à accueillir notre application](#2.1-creation-ami)
  * [2. Création d'une instance EC2 via `CloudFormation`](#2.2-creation-instance-ec2)
  * [3. Déploiement - 1e étape - Copier la sortie du stage `Build` sur l'instance EC2](#2.3-deploy-1-copy-build-output-raw)
- [Références](#references)


###  <a name="introduction-description-du-projet"></a> Introduction

Cette article est le 2e d'une série. Voir aussi:
- [partie 1](https://joseph-mbimbi.fr/blog/codebuild-test-report-demo-part-1)

Le but de cette série d'article est de mettre en place une pipeline de CI/CD d'une application Java dans des instances EC2 dans un autoscaling group derrière un Load Balancer, avec des tests automatisés et la publication de rapports de test.

Nous commençons par rappeler la cible, les étapes pour y arriver, et le scope de cet article.
Ensuite, nous effectuerons l'implémentation pas à pas, avec des tags git pour pouvoir revenir sur les rails en cas de décrochage (ce qui est inévitable, on oublie toujours une action ou une étape)

Bon code

#### <a name="cible"></a> Rappel de la cible

Le but de la série d'articles est d'avoir au final:
- une application Java de base
- une pipeline de CI/CD déployant l'application dans plusieurs instances EC2 derrière un Load Balancer
- des tests unitaires et "d'intégration" (`mvn verify`) sont éxécutés lors de la phase de `Build` de la pipeline
- des tests automatisés sont éxécutés sur l'application après son déploiement dans un environnement de test
- un rapport sur le résultats des "tests unitaires" (`mvn verify`) est publié
- un rapport sur la couverture des "tests unitaires" (`mvn verify`) est publié
- un rapport sur l'éxécution de tests automatisés sur l'environnement de test est publié

#### <a name="etapes"></a> Rappel des étapes

Nous allons réaliser la cible par les étapes suivantes:
1. Mise en place d'une pipeline de "Build" de l'application (pas encore de déploiement), avec éxécuton des tests unitaires et publication des rapports de test
2. Déploiement de l'application dans une instance EC2, avec éxécution de test sur cet instance et publication d'un rapport de test
3. Déploiement dans plusieurs instances derrière un Load Balancer, avec éxécution de tests au niveau du Load Balancer et publication de rapport de tests


#### <a name="plan-article"></a> Plan de l'article

Dans cet article, nous allons réaliser l'étape n°2, à savoir:

- Déploiement de l'application dans une instance EC2
- Test de l'application sur cet environnement
- Publication d'un rapport de test sur l'application déployée 


### <a name="implementation-cloudformation"></a> Implémentation avec `CloudFormation`

#### <a name="2.0-refacto-intro-makefile-infra"></a> 0. Refacto - Introduction d'un `Makefile` pour la création et la destruction des éléments d'infra

tag de départ: `1.13-buildtime-integation-test-cucumber`
tag d'arrivée: `2.0-refacto-intro-makefile-infra`

Dans cette étape, nous allons refacto un peu notre code d'infra. Au lieu d'utiliser un script shell qui fait tout, nous allons introduire un `Makefile` pour nous permettre de créer toute l'infra, ou juste une partie, de manière un peu plus propre.

Il y a probablement une meilleure manière de faire, mais pour le moment ça fera très bien l'affaire.

1. Nous introduisons le Makefile suivant:

```makefile
SHELL := /bin/bash
ifndef APPLICATION_NAME
$(error APPLICATION_NAME is not set)
endif
include infra.env
PIPELINE_STACK_NAME=$(APPLICATION_NAME)-pipeline

all:
	- $(MAKE) pipeline
pipeline:
	./create-pipeline.sh $(APPLICATION_NAME) $(PIPELINE_STACK_NAME)  $(GITHUB_REPO) $(GITHUB_REPO_BRANCH)

delete-all:
	- $(MAKE) delete-pipeline
delete-pipeline:
	./delete-stack-wait-termination.sh $(PIPELINE_STACK_NAME)
```

2. Nous déplaçons le script `create-all.sh` dans le répertoire `infra`, nous le renommons `create-pipeline.sh`, et nous le modifions, de manière à ce que toutes les variables soient transmises en paramètres d'appel du script. Cela a paru approprié sur le moment

```shell
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
```

Nous introduisons un script pour supprimer une stack `CloudFormation` quelconque, et qui attend la fin de la suppression. Sans rentrer dans les détails, cela nous évitera des problèmes ultérieurs

```shell
#!/bin/bash

if [[ -z $1 ]]; then
  echo -e "usage:\n./delete-stack-wait-termination.sh \$STACK_NAME"
  exit 1
fi

STACK_NAME=$1

echo -e "##############################################################################"
echo -e "force deleting S3 buckets for stack $STACK_NAME"
echo -e "##############################################################################"
S3_BUCKETS=$(aws cloudformation describe-stack-resources --stack-name $STACK_NAME --query "StackResources[?ResourceType=='AWS::S3::Bucket'].PhysicalResourceId" --output text)
for S3_BUCKET in $S3_BUCKETS
do
  aws s3 rb s3://$S3_BUCKET --force
done

echo -e "##############################################################################"
echo -e "deleting stack $STACK_NAME"
echo -e "##############################################################################"
aws cloudformation delete-stack --stack-name $STACK_NAME
aws cloudformation wait stack-delete-complete --stack-name $STACK_NAME
```

suppression de variables inutilisées et/ou sources d'erreur avec `Makefile`:
```shell
export AWS_REGION=$(aws configure get region)
export ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
```

Si vous avez toujours les stacks `CloudFormation` créées dans la partie précédente, profitons-en pour vérifier que le `Makefile` fonctionne bien:

```shell
cd infra
make delete-all APPLICATION_NAME=my-app
```

la stack de la pipeline devrait bien être supprimée:

![](images/0.1-refacto-introduction-make.png)

Recréons la pipeline:

```shell
cd infra #si vous n'y êtes pas deja
make all APPLICATION_NAME=my-app
```

Inspectons la stack `CloudFormation`:

![](images/0.2-refacto-introduction-make.png)

Après avoir activé la connexion github et éventuellement relancé la pipeline si celle-ci a échoué, vous devriez avoir au final une pipeline verte:

![](images/0.3-refacto-introduction-make.png)

Et les rapports de tests devraient bien être uploadés:

![](images/0.4-refacto-introduction-make.png)

#### <a name="2.1-creation-ami"></a> 1. Création d'une AMI (image EC2) prête à accueillir notre application

tag de départ: `2.0-refacto-intro-makefile-infra`
tag d'arrivée: `2.1-creation-ami`

Dans cette étape, nous allons créer une AMI avec toutes les dépendances et configuration nécessaires pour faire tourner notre application Java. 
Nous nous baserons sur l'outil `Packer` et nous baserons sur une AMI de base `Ubuntu Server 20.04`.
Il existe aussi l'outil d'AWS `EC2 Builder`, mais au moment de la rédaction de cette article, je ne suis pas assez familier avec EC2 Builder, je connais un peu mieux `Packer`, j'ai deja un side project avec sur lequel je peux m'appuyer, je n'ai pas trop envie d'y passer beaucoup de temps, et la création d'AMI n'est pas le but principal de la série d'articles.
Cependant, `EC2 Builder` fera très certainement l'objet d'un prochain side project et d'un article associé.

##### 2.1.1 Création de l'AMI avec Packer

Les actions réalisées sont:

1. ajout du fichier `infra/packer-ami/ubuntu-springboot-ready.json`, qui sera utilisé par `Packer` pour créer notre AMI:

```json
{
  "variables": {
    "ami_id": "",
    "ami_name": "",
    "region": ""
  },
  "builders": [
    {
      "type": "amazon-ebs",
      "access_key": "",
      "secret_key": "",
      "region": "{{user `region`}}",
      "ami_name": "{{user `ami_name`}}",
      "instance_type": "t2.micro",
      "source_ami": "{{user `ami_id`}}",
      "ssh_username": "ubuntu"
    }
  ],
  "provisioners": [
    {
      "type": "shell",
      "script": "setup.sh"
    }
  ]
}
```

Décortiquons un peu ce fichier:

![](images/1.1-creation-ami.png)

a. On définit des varibles pour notre config `Packer`
b. Des configs de l'instance EC2 utilisée pour constituer notre AMI
  - b.1 On note la présence des varibles définies plus haut
c. Le provisionner est de type `shell` et on utilise le script `setup.sh` juste à côté du fichier json, dont on parlera juste après

2. ajout du fichier `infra/packer-ami/setup.sh`, qui sera utilisé par `Packer` pour provisionner l'instance EC2 à partir de laquelle nous allons créer notre AMI:

```shell
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
```

Le script devrait être assez court et lisible, mais, en reprenant les commentaires, on peut le résumer de la manière suivante

a. on installe quelques utilitaires
b. on installe java
c. on installe l'agent `CodeDeploy` -> `CodeDeploy` est un service AWS permettant ... de déployer des applications: dans EC2, ECS, Lambda, etc. mais contrairement à `Ansible` par exemple, cet outil nécessite un agent, qui va "pull" tout ce qu'il y a à déployer

3. On ajoute un script `infra/create-ami.sh`, qui wrappe l'appel à `Packer`:

```shell
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
```

On modifie le `Makefile`, de manière à rajouter les targets: `ami` et `delete-ami`, dont le nom devrait être suffisamment explicite

```makefile
#[...]
all:
	- $(MAKE) pipeline
	- $(MAKE) ami
ami:
	$(eval BASE_AMI_ID := $(shell aws ssm get-parameters --names /aws/service/canonical/ubuntu/server/20.04/stable/current/amd64/hvm/ebs-gp2/ami-id --query 'Parameters[0].[Value]' --output text))
	$(eval AWS_REGION := $(shell aws configure get region))
	./create-ami.sh $(APPLICATION_NAME) $(BASE_AMI_ID) $(AWS_REGION)
#[...]
delete-ami:
	$(eval AMI_ID := $(shell aws ec2 describe-images --owners self --query "Images[?Name=='$(APPLICATION_NAME)'].ImageId" --output text))
	aws ec2 deregister-image --image-id $(AMI_ID)
```

Vérifions que tout cela fonctionne, en déclenchant la target `ami` ou `all` (qui sont le facto "idempotent"):

```shell
cd infra #si vous n'y êtes pas deja
make all APPLICATION_NAME=my-app
```

La création de l'AMI est assez longue et prend chez moi environ 10-15 minutes, soyez patients.

Vérifions dans la console AWS:

![](images/1.3-creation-ami.png)

##### 2.1.2 Création manuelle d'une instance EC2 à partir de notre image

Créons rapidement une instance à partir de cette AMI, dans la console, cliquez sur "Actions > Launch":

![](images/1.4-creation-ami.png)

Cliquez sur "Review and Launch":

![](images/1.5-creation-ami.png)

Cliquez sur "Launch":

![](images/1.6-creation-ami.png)

Si vous avez deja une paire de clés ssh et que vous êtes familier avec la procédure, sélectionnez une paire de clés existante.

Sinon:
- sélectionnez `Create a new key pair` au lieu de `Choose an existing key pair`

![](images/1.7-creation-ami.png)

1. donnez par exemple le nom "keys" à la paire de clés
2. téléchargez le fichier `keys.pem`
3. cliquez sur "Launch Instances"

![](images/1.8-creation-ami.png)

Dans le menu de gauche, allez dans "Instances", vous devriez voir votre instance dans l'état "Running" au bout d'une poignée de minutes maximum:

![](images/1.8-creation-ami.png)

Nous allons nous y connecter en ssh. Il y a plusieurs manières de l'effectuer, allons au plus facile:
- cliquez sur "Connect":

![](images/1.10-creation-ami.png)

Dans la fenêtre suivante:
1. sélectionnez "EC Instance Connect" 
2. cliquez sur "Connect"

![](images/1.11-creation-ami.png)

Un nouvel onglet s'ouvre, avec un terminal:

![](images/1.12-creation-ami.png)

1. On est loggé en tant que `root`
2. On peut vérifier l'installation de java avec `java -version`
3. On peut vérifier l'installation et l'état de l'agent `CodeDeploy` avec `systemctl status codedeploy-agent.service`

Prochaine étape, automatiser cette création d'instance 

#### <a name="2.2-creation-instance-ec2"></a> 2. Création d'une instance EC2 via `CloudFormation`

tag de départ: `2.1-creation-ami`
tag d'arrivée: `2.2-creation-instance-ec2`

Le titre est assez explicite, dans cette étape, nous allons créer une instance EC2 avec `CloudFormation` 

Pour cela, nous allons effectuer les actions, ajouts, modifications suivantes:

1. Import d'une paire de clés SSH dans le compte AWS

  - fichier `infra/create-ssh-key-pair.sh` 

```shell
#!/bin/bash

if [[ "$#" -ne 2 ]]; then
  echo -e "usage:\n./create-all.sh \$SSH_KEY_NAME \$SSH_KEY_PATH"
  exit 1
fi

export SSH_KEY_NAME=$1
export SSH_KEY_PATH=$2

echo -e "##############################################################################"
echo -e "creating ssh key pair \"$SSH_KEY_NAME\" from $SSH_KEY_PATH"
echo -e "##############################################################################"
PUBLIC_KEY_BASE_64=$(cat $SSH_KEY_PATH | base64)
aws ec2 import-key-pair --key-name $SSH_KEY_NAME --public-key-material "$PUBLIC_KEY_BASE_64"
```

On ne peut pas créer de paire de clés SSH via `CloudFormation`, on se contera de la CLI AWS dans ce cas. 

Que dire de particulier, il faut transmettre le contenu de la clé publique encodé en base64.

  - fichier `infra/infra.env`

```dotenv
export GITHUB_REPO=mbimbij/codebuild-test-report-demo # deja présent
export GITHUB_REPO_BRANCH=main                        # deja présent
export SSH_KEY_NAME=local
export SSH_KEY_PATH=~/.ssh/id_rsa.pub
```

Pour cette démo, on utilise la clé publique: `~/.ssh/id_rsa.pub`, que l'on uploadera avec l'id `local`. 

Ainsi, si vous avez deja une paire de clés (et en tant que programmeur, sous linux, je présume que c'est le cas), cela devrait faciliter l'utilisation de ce projet / tutorial, et la connexion à l'instance EC2.

2. Ajout d'un template `CloudFormation` pour l'instance EC2, fichier `infra/execution-environment-cfn.yml`:

```yaml
Parameters:
  ApplicationName:
    Type: String
    Description: Application Name
  KeyName:
    Type: String
    Description: Key Name
  AmiId:
    Type: AWS::EC2::Image::Id
    Description: Ami Id

Resources:
  Ec2SecurityGroup:
    Type: AWS::EC2::SecurityGroup
    Properties:
      GroupDescription: ec2 security group
      SecurityGroupIngress:
        - IpProtocol: tcp
          FromPort: 22
          ToPort: 22
          CidrIp: 0.0.0.0/0
        - IpProtocol: tcp
          FromPort: 8080
          ToPort: 8080
          CidrIp: 0.0.0.0/0
  Ec2Instance:
    Type: AWS::EC2::Instance
    Properties:
      ImageId: !Ref AmiId
      InstanceType: t2.micro
      KeyName: !Ref KeyName
      SecurityGroups:
        - !Ref Ec2SecurityGroup
      Tags:
        - Key: Name
          Value: !Sub '${ApplicationName}-instance'
        - Key: Application
          Value: !Sub '${ApplicationName}'
```

Analysons ce template:

![](images/2.1-creation-instance-ec2.png)

- 1. On définit un `Security Group` autorisant les connexions entrantes sur les ports: 
  - 22, pour pouvoir y accéder en ssh
  - 8080, car c'est le port par défaut sur lequel se binde les applications `SpringBoot`, que nous allons utiliser par la suite.
- 2. On fait référence à un paramètre `AmiId`, dans lequel on placera l'id de l'AMI que l'on a créé dans l'étape #1
- 3. On fait référence à la paire de clés définie juste avant, qui est la clé ssh publique de notre poste de développement
- 4. On associe le `security group` à l'instance
- 5. On définit un tag "Name", afin que l'instance ait un nom dans la console AWS
- 6. On définit un tag "Application", ayant le nom de l'application. Plus tard, on utilisera ce nom pour le déploiement


3. modifications dans le fichier `infra/Makefile` :

```makefile
SHELL := /bin/bash
ifndef APPLICATION_NAME
$(error APPLICATION_NAME is not set)
endif
include infra.env
PIPELINE_STACK_NAME=$(APPLICATION_NAME)-pipeline
EXECUTION_ENVIRONMENT_STACK_NAME=$(APPLICATION_NAME)-execution-environment

all:
	- $(MAKE) pipeline
	- $(MAKE) ami
	- $(MAKE) execution-environment
pipeline:
	./create-pipeline.sh $(APPLICATION_NAME) $(PIPELINE_STACK_NAME) $(GITHUB_REPO) $(GITHUB_REPO_BRANCH)
ami:
	$(eval BASE_AMI_ID := $(shell aws ssm get-parameters --names /aws/service/canonical/ubuntu/server/20.04/stable/current/amd64/hvm/ebs-gp2/ami-id --query 'Parameters[0].[Value]' --output text))
	$(eval AWS_REGION := $(shell aws configure get region))
	./create-ami.sh $(APPLICATION_NAME) $(BASE_AMI_ID) $(AWS_REGION)
ssh-key-pair:
	./create-ssh-key-pair.sh $(SSH_KEY_NAME) $(SSH_KEY_PATH)
execution-environment: ssh-key-pair
	$(eval AMI_ID := $(shell aws ec2 describe-images --owners self --query "Images[?Name=='$(APPLICATION_NAME)'].ImageId" --output text))
	./create-execution-environment.sh $(APPLICATION_NAME) $(EXECUTION_ENVIRONMENT_STACK_NAME) $(AMI_ID) $(SSH_KEY_NAME)


delete-all:
	- $(MAKE) delete-pipeline
delete-pipeline:
	./delete-stack-wait-termination.sh $(PIPELINE_STACK_NAME)
delete-ami:
	$(eval AMI_ID := $(shell aws ec2 describe-images --owners self --query "Images[?Name=='$(APPLICATION_NAME)'].ImageId" --output text))
	aws ec2 deregister-image --image-id $(AMI_ID)
delete-ssh-key-pair:
	aws ec2 delete-key-pair --key-name $(SSH_KEY_NAME)
delete-execution-environment: delete-ssh-key-pair
	./delete-stack-wait-termination.sh $(EXECUTION_ENVIRONMENT_STACK_NAME)
```

Jetons un oeil du côté des ajouts effectués:

![](images/2.2-creation-instance-ec2.png)

Pas grand chose à ajouter, un ajoute des targets pour créer la paire de clés et l'instance, ainsi que pour les détruire

Vérifions la création :

```shell
cd infra #si vous n'y êtes pas deja
make all APPLICATION_NAME=my-app
```

![](images/2.3-creation-instance-ec2.png)

L'instance est bien créé. Vérifions que l'on peut s'y connecter en utilisant notre clé ssh par défaut (sans l'expliciter)

![](images/2.4-creation-instance-ec2.png)

Parfait ! Prochaine étape, revenir sur la pipeline, et réussir à pousser la sortie de l'étape de build sur l'instance EC2. Première étape pour déployer l'application Java

#### <a name="2.3-deploy-1-copy-build-output-raw"></a> 3. Déploiement - 1e étape - Copier la sortie du stage `Build` sur l'instance EC2 

tag de départ: `2.2-creation-instance-ec2`
tag d'arrivée: `2.3-deploy-1-copy-build-output-raw`

Dans cette étape, nous allons créer un "stage" de déploiement dans la pipeline. Pour rester dans une approche baby-step, nous allons nous contenter de copier la sortie brute du stage "Build" de cette même pipeline.

Pour cela nous effectuons les actions suivantes:

1. Modification du template de la Pipeline, `infra/pipeline-cfn.yml`, pour y ajouter un stage "Deploy"
  - 1.1 Ajout d'une permission au rôle `PipelineRole` pour lui permettre d'éxécuter des déploiements basés sur `CodeDeploy`

```yaml
- Effect: Allow
  Action:
    - codedeploy:*
  Resource: !Sub 'arn:${AWS::Partition}:codedeploy:${AWS::Region}:${AWS::AccountId}*'
```
  - 1.2 Modification du `buildspec` dans la ressource `BuildProject` afin de copier tous les fichiers dans les "OutputArtifacts"

```yaml
artifacts:
  files:
    - '**/*'
```

  - 1.3 Ajout d'une ressource: `CodeDeployApplication` qui sera le projet / application `CodeDeploy`
  
```yaml
CodeDeployApplication:
  Type: AWS::CodeDeploy::Application
  Properties:
    ApplicationName: !Sub '${ApplicationName}-deploy-application'
    ComputePlatform: Server
```

  - 1.4 Ajout d'une ressource: `CodeDeployDeploymentGroup` -> un groupe de déploiement de l'application précédente, qui va concrètement procéder au déploiement, à partir d'un fichier `appspec.yml` dans les artefacts en entrée
    
```yaml
CodeDeployDeploymentGroup:
  Type: AWS::CodeDeploy::DeploymentGroup
  Properties:
    ApplicationName: !Ref CodeDeployApplication
    ServiceRoleArn: !GetAtt
      - CodeDeployRole
      - Arn
    DeploymentGroupName: !Sub '${ApplicationName}-deployment-group'
    DeploymentConfigName: CodeDeployDefault.OneAtATime
    Ec2TagFilters:
      - Key: Application
        Value: !Ref ApplicationName
        Type: KEY_AND_VALUE
```

  - 1.5 Ajout d'une ressource: `CodeDeployRole` -> le rôle que va utiliser le groupe de déploiement. On lui attache une policy managée par AWS: `AWSCodeDeployRole`

```yaml
CodeDeployRole:
  Type: 'AWS::IAM::Role'
  Description: IAM role for !Ref ApplicationName code deploy deployment group
  Properties:
    RoleName: !Join
      - '-'
      - - !Ref ApplicationName
        - deploy-role
    AssumeRolePolicyDocument:
      Statement:
        - Action: "sts:AssumeRole"
          Effect: Allow
          Principal:
            Service:
              - codedeploy.amazonaws.com
    ManagedPolicyArns:
      - arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole
```

  - 1.6 Ajout d'un stage `Deploy` à la ressource: `Pipeline`

```yaml
- Name: Deploy
  Actions:
    - Name: Deploy
      InputArtifacts:
        - Name: BuildOutput
      ActionTypeId:
        Category: Deploy
        Owner: AWS
        Version: 1
        Provider: CodeDeploy
      Configuration:
        ApplicationName:
          Ref: CodeDeployApplication
        DeploymentGroupName:
          Ref: CodeDeployDeploymentGroup
      RunOrder: 1
```

2. Modification du template de l'instance ec2, `infra/execution-environment-cfn.yml`

![](images/3.1-deploy-raw-build-output.png)
  - 2.1 On associe à l'instance EC2 le profile `Ec2InstanceProfile`
  - 2.2 On définit la ressource pour le profile `Ec2InstanceProfile`, on y associant le rôle IAM `Ec2InstanceRole`
  - 2.3 On définit le rôle IAM `Ec2InstanceRole`, ayant les policies managées
    - `AmazonEC2RoleforAWSCodeDeploy`, pour permettre à l'agent `codedeploy` de récupérer les artefacts depuis S3
    - `AmazonSSMManagedInstanceCore`, pour permettre à l'instance de s'enregistrer auprès de `System Manager`. Sans cela, le déploiement reste indéfiniment dans l'état `Pending`, sans absolument aucune log ... 

3. Un fichier `appspec` ultra minimaliste. La présence de ce fichier est obligatoire

```yaml
version: 0.0
os: linux
```

... Et rien de plus !

Mettons à jour notre infra: 

```shell
cd infra #si vous n'y êtes pas deja
make all APPLICATION_NAME=my-app
```

poussons le code dans le repo git relançons une release dans la pipeline si elle n'est pas déclenchée automatiquement. Tout devrait être vert:

![](images/3.2-deploy-raw-build-output.png)

Allons jeter un oeil au déploiement dans `CodeDeploy`. Dans "Deploy > Deployments", rafraîchir éventuellement:

![](images/3.3-deploy-raw-build-output.png)

J'ai plusieurs déploiement dans mon screenshot, en espérant que cela ne soit pas source de confusion.

Notons l'id du dernier déploiement

connectons-nous en ssh sur l'instance EC2 :

```shell
Last login: Thu May 27 08:15:01 2021 from 176.173.232.167
ubuntu@ip-172-31-40-53:~$ cd /opt/codedeploy-agent/deployment-root/<some-deployment-group-id>/<last-deployment-id>/deployment-archive/
ubuntu@ip-172-31-40-53:/opt/codedeploy-agent/deployment-root/1abcd735-aa71-4a4d-8f68-ccc88a65d2e4/d-C1CX5XBU8/deployment-archive$ ls
README.md  appspec.yml  blog-article  infra  pom.xml  reposition-tag.sh  src  target
```

l'id du groupe de déploiement, ainsi que du dernier déploiement, seront différents chez vous.

Cependant, on peut constater que le code source et le répertoire `target` sont bien présents dans l'instance EC2. 

Félicitations, nous avons bien réssui à effectuer un premier déploiement.

Prochaine étape, créer une interface REST dans le code `Java`, déployer l'application en tant que service et vérifier que tout fonctionne bien.  

## <a name="references"></a> Références
- code source github: [https://github.com/mbimbij/codebuild-test-report-demo](https://github.com/mbimbij/codebuild-test-report-demo)
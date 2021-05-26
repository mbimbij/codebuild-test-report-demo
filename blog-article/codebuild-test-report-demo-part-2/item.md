
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

## <a name="references"></a> Références
- code source github: [https://github.com/mbimbij/codebuild-test-report-demo](https://github.com/mbimbij/codebuild-test-report-demo)
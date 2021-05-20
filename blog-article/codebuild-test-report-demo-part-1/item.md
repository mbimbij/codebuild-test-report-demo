
---
title: Pipeline CI/CD d'une application Java dans EC2 - partie 1
date: 15:30 05/21/2021
author: Joseph M'Bimbi-Bene
hero_classes: 'text-light overlay-dark-gradient'
hero_image: codebuild.png
taxonomy:
category: blog
tag: [devops, cloud, tests]
---

Dans cette article, nous allons développer une pipeline de CI pour une application Java, et publier des rapports de test et de couverture de test dans `CodeBuild`.

===


### Sommaire

- [Introduction, Description du projet](#introduction-description-du-projet)
  * [Cible](#cible)
  * [Etapes](#etapes)
  * [Plan de l'article](#plan-article)
- [Implémentation avec `CloudFormation`](#implementation-cloudformation)
- [Références](#references)

<small><i><a href='http://ecotrust-canada.github.io/markdown-toc/'>Table of contents generated with markdown-toc</a></i></small>


###  <a name="introduction-description-du-projet"></a> Introduction, Description du projet

Dans cette série d'articles, nous allons développer une application Java backend très simple, typiquement composée uniquement d'une classe renvoyant une `String` en dur.

Cette application sera accompagnée d'une pipeline de CI/CD avec éxécution de tests unitaires et de tests automatisés, éxécutés sur l'application déployée sur une ou plusieurs instances EC2.
Les rapports d'éxécution et de couverture des tests seront publiés dans `CodeBuild`

Le but est d'avoir un point de départ réutilisable, fournissant un exemple simple, permettant de réimplémenter cette logique de pipeline et de publication de rapports de tests sur des projets plus compliqués.

#### <a name="cible"></a> Cible

Le but de la série d'articles et d'avoir au final:
- une application Java de base
- une pipeline de CI/CD déployant l'application dans plusieurs instances EC2 derrière un Load Balancer
- des tests unitaires et "d'intégration" (`mvn verify`) sont éxécutés lors de la phase de `Build` de la pipeline
- des tests automatisés sont éxécutés sur l'application après son déploiement dans un environnement de test
- un rapport sur le résultats des "tests unitaires" (`mvn verify`) est publié
- un rapport sur la couverture des "tests unitaires" (`mvn verify`) est publié
- un rapport sur l'éxécution de tests automatisés sur l'environnemnet de test est publié

#### <a name="etapes"></a> Etapes

Nous allons réaliser la cible par les étapes suivantes:
1. Mise en place d'une pipeline de "Build" de l'application (pas encore de déploiement), avec éxécuton des tests unitaires et publication des rapports de test
2. Déploiement de l'application dans une instance EC2, avec éxécution de test sur cet instance et publication d'un rapport de test
3. Déploiement dans plusieurs instances derrière un Load Balancer, avec éxécution de tests au niveau du Load Balancer et publication de rapport de tests


#### <a name="plan-article"></a> Plan de l'article

Dans cet article, nous allons réaliser l'étape n°1, à savoir:

- Mise en place d'une pipeline de "Build" de l'application (pas encore de déploiement)
- éxécution de tests unitaires et "d'intégration" (`mvn verify`), avec Junit et Cucumber
- publication des rapports d'éxécution et de couverture des tests


### <a name="implementation-cloudformation"></a> Implémentation avec `CloudFormation`

### 1. Mise en place d'un Bucket S3 pour la pipeline de CI/CD

tag de départ: `1.1-initial-commit`
tag d'arrivée: `1.2-s3-bucket`

Nous créons un bucket S3 avec le template `CloudFormation` suivant:

```yaml
Parameters:
  ApplicationName:
    Type: String
    Description: Application Name

Resources:
  S3Bucket:
    Type: 'AWS::S3::Bucket'
    Description: S3 bucket for pipeline artifacts
    Properties:
      BucketName: !Join
        - '-'
        - - !Ref 'AWS::Region'
          - !Ref 'AWS::AccountId'
          - !Ref ApplicationName
          - bucket-pipeline
```

Nous créons aussi les 2 scripts suivants pour nous faciliter le travail d'installation et de destruction de l'infra:
- `create-all.sh`
- `delete-all.sh`

Nous pouvons créer le bucket S3 via la commande suivante:
```shell
./create-all.sh my-app
```

Vérifions la bonne éxécution création du bucket de la stack `CloudFormation`:
![](images/1-s3_cfn.png)

Vérifions la création du bucket S3:
![](images/2-s3_cfn.png)

### 2. Mise en place d'une connexion Github
tag de départ: `1.2-s3-bucket`
tag d'arrivée: `1.3-github-connection`

Nous rajoutons la ressource `CloudFormation` suivante pour créer la connexion `Github`:

```yaml
GithubConnection:
  Type: AWS::CodeStarConnections::Connection
  Properties:
    ConnectionName: !Ref ApplicationName
    ProviderType: GitHub
```

updatons la stack `CloudFormation` via le script helper:
```shell
./create-all.sh my-app
```

On vérifie la bonne éxécution de l'update de la stack:
![](images/3-github-connection.png)

Et la présence de la connexion Github:
![](images/3.1-github-connection.png)

Les connexion github créées par `CloudFormation` ou la CLI AWS sont toujours pending et doivent être activées à la main.
Pour autant que l'auteur le sache, il n'y a pas de moyen d'activer automatiquement une connexion (sauf bricolage avec quelque chose comme Sélénium éventuellement).
Voir [https://docs.aws.amazon.com/dtconsole/latest/userguide/connections-update.html](https://docs.aws.amazon.com/dtconsole/latest/userguide/connections-update.html)

    A connection created through [...] AWS CloudFormation is in PENDING status by default [...]
    You **must** use the console to update a pending connection. You cannot update a pending connection using the AWS CLI.


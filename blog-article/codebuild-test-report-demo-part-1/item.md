
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
  * [1. Mise en place d'un Bucket S3 pour la pipeline de CI/CD](#1.2-s3-bucket)
  * [2. Mise en place d'une connexion Github](#1.3-github-connection)
  * [3. Mise en place d'un rôle IAM pour CodeBuild](#1.4-codebuild-iam-role)
  * [4. Mise en place d'un rôle IAM pour CodePipeline](#1.5-codepipeline-iam-role)
  * [5. Mise en place d'un projet CodeBuild](#1.6-codebuild-project)
  * [6. Mise en place d'un projet CodePipeline](#1.7-codepipeline-project)
  * [7. Mise en place d'un projet Java avec éxécution d'un test unitaire "build time" en Junit - local](#1.8-buildtime-test-junit-execution-local)
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
- un rapport sur l'éxécution de tests automatisés sur l'environnement de test est publié

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

### <a name="1.2-s3-bucket"></a> 1. Mise en place d'un Bucket S3 pour la pipeline de CI/CD

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

### <a name="1.3-github-connection"></a> 2. Mise en place d'une connexion Github
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

### <a name="1.4-codebuild-iam-role"></a> 3. Mise en place d'un rôle IAM pour CodeBuild
tag de départ: `1.3-github-connection`
tag d'arrivée: `1.4-codebuild-iam-role`

Dans cette étape, nous créons un rôle qui sera endossé par le futur projet `CodeBuild`, ainsi que les permissions associées.
Ce qui se traduit par la ressource `CloudFormation` suivante:

```yaml
BuildProjectRole:
  Type: 'AWS::IAM::Role'
  Description: IAM role for !Ref ApplicationName build resource
  Properties:
    RoleName: !Join
      - '-'
      - - !Ref ApplicationName
        - build-role
    Path: /
    Policies:
      - PolicyName: !Join
          - '-'
          - - !Ref ApplicationName
            - build-policy
        PolicyDocument:
          Statement:
            - Effect: Allow
              Action:
                - s3:PutObject
                - s3:GetObject
                - s3:GetObjectVersion
                - s3:GetBucketAcl
                - s3:GetBucketLocation
              Resource:
                - !Sub 'arn:${AWS::Partition}:s3:::${S3Bucket}'
                - !Sub 'arn:${AWS::Partition}:s3:::${S3Bucket}/*'
            - Effect: Allow
              Action:
                - logs:CreateLogGroup
                - logs:CreateLogStream
                - logs:PutLogEvents
              Resource: !Sub 'arn:${AWS::Partition}:logs:${AWS::Region}:${AWS::AccountId}:log-group:/aws/codebuild/*'
            - Effect: Allow
              Action:
                - codebuild:CreateReportGroup
                - codebuild:CreateReport
                - codebuild:UpdateReport
                - codebuild:BatchPutTestCases
                - codebuild:BatchPutCodeCoverages
              Resource: !Sub 'arn:${AWS::Partition}:codebuild:${AWS::Region}:${AWS::AccountId}:report-group/${ApplicationName}-*'
    AssumeRolePolicyDocument:
      Statement:
        - Action: "sts:AssumeRole"
          Effect: Allow
          Principal:
            Service:
              - codebuild.amazonaws.com
```

Analysons un peu ce que l'on vient de rajouter:
Nous avons donc créé un "rôle", l'équivalent AWS d'une "carte d'accès", qui définit: 
- quels sont les permission liés à ce rôle (la carte donne accès à quoi ?)
- quels services peut "assumer" le rôle (qui a le droit de porter cette carte ?)

Voyons ce que cela donne dans notre rôle:
![](images/4.1-codebuild-iam-role.png)

1. Nous donnons au rôle le droit d'effectuer la liste d'opération définie dans `Action`, pour le bucket S3 que l'on a créé précédemment
2. Nous donnons au rôle le droit de créer des logs auprès d'un service nommé `CloudWatch logs`. On note que sans ces droits, le projet `CodeBuild` ne pourra pas s'éxécuter

![](images/4.2-codebuild-iam-role.png)

3. Nous donnons au rôle le droit de publier des rapports de tests, puisque c'est le but principal de ce projet pour commencer
4. Nous définissons qui a le droit d'assumer le rôle, ici les projets de type `CodeBuild`

updatons la stack `CloudFormation` via le script helper:
```shell
./create-all.sh my-app
```

On vérifie la bonne éxécution de la mise à jour de la stack, ainsi que la création de la nouvelle ressource:
![](images/4.3-codebuild-iam-role.png)

On vérifie rapidement les permissions sur le rôle nouvellement créé:
![](images/4.4-codebuild-iam-role.png)

### <a name="1.5-codepipeline-iam-role"></a> 4. Mise en place d'un rôle IAM pour CodePipeline
tag de départ: `1.4-codebuild-iam-role`
tag d'arrivée: `1.5-codepipeline-iam-role`

Dans cette étape, nous créons un rôle qui sera endossé par le futur projet `CodePipeline`, ainsi que les permissions associées.
Ce qui se traduit par la ressource `CloudFormation` suivante:

```yaml
PipelineRole:
  Type: 'AWS::IAM::Role'
  Description: IAM role for !Ref ApplicationName pipeline resource
  Properties:
    RoleName: !Join
      - '-'
      - - !Ref ApplicationName
        - pipeline-role
    Path: /
    Policies:
      - PolicyName: !Join
          - '-'
          - - !Ref ApplicationName
            - pipeline-policy
        PolicyDocument:
          Statement:
            - Effect: Allow
              Action:
                - codestar-connections:UseConnection
              Resource: !Ref GithubConnection
            - Effect: Allow
              Action:
                - s3:PutObject
                - s3:GetObject
                - s3:GetObjectVersion
                - s3:GetBucketAcl
                - s3:PutObjectAcl
                - s3:GetBucketLocation
              Resource:
                - !Sub 'arn:${AWS::Partition}:s3:::${S3Bucket}'
                - !Sub 'arn:${AWS::Partition}:s3:::${S3Bucket}/*'
    AssumeRolePolicyDocument:
      Statement:
        - Action: "sts:AssumeRole"
          Effect: Allow
          Principal:
            Service:
              - codepipeline.amazonaws.com
```

Ici aussi, analysons le rôle créé:
![](images/5.1-codepipeline-iam-role.png)

1. Nous donnons au rôle la permission d'utiliser la connexion `Github` définie dans l'étape #2
2. Nous donnons au rôle la permission de lire et écrire vers le bucket S3 défini dans l'étape #1, la pipeline *utilise* la connexion `Github`, mais c'est elle-même qui va récupérer le code source et le pousser dans le bucket s3, il n'y a pas de délégation de l'action vers un autre service

![](images/5.2-codepipeline-iam-role.png)

3. Nous définissons qui a le droit d'assumer le rôle, ici les services de type `CodePipeline`

updatons la stack `CloudFormation` via le script helper:
```shell
./create-all.sh my-app
```

On vérifie la bonne éxécution de la mise à jour de la stack, ainsi que la création de la nouvelle ressource:
![](images/5.3-codepipeline-iam-role.png)

On jette un oeil au rôle IAM créé et aux policies qui lui sont attachées:
![](images/5.4-codepipeline-iam-role.png)

### <a name="1.6-codebuild-project"></a> 5. Mise en place d'un projet CodeBuild
tag de départ: `1.5-codepipeline-iam-role`
tag d'arrivée: `1.6-codebuild-project`

Dans cette partie, nous allons rajouter un projet `CodeBuild`, qui sera déclenché par `CodePipeline`.

Nous commençons par le projet `CodeBuild` car un projet `CodePipeline` doit avoir au minimum 2 "stages", qui seront dans notre cas : "Source", "Build".
Le stage "Source" a deja été anticipé par la création de la connexion `Github`, maintenant on s'occupe d'anticiper le stage "Build".

Voici les mises à jour qui sont effectuées dans le template `CloudFormation`:

```yaml
Parameters:
  [...]
  GithubRepo:
    Type: String
    Description: Github source code repository
  GithubRepoBranch:
    Default: 'main'
    Type: String
    Description: Github source code branch

Resources:
  [...]
  PipelineRole:
    Properties:
      Policies:
          PolicyDocument:
            Statement:
              [...]
              - Effect: Allow
                Action:
                  - codebuild:BatchGetBuilds
                  - codebuild:StartBuild
                  - codebuild:BatchGetBuildBatches
                  - codebuild:StartBuildBatch
                Resource: !GetAtt
                  - BuildProject
                  - Arn
  [...]
  BuildProject:
    Type: AWS::CodeBuild::Project
    Properties:
      Name: !Join
        - '-'
        - - !Ref ApplicationName
          - build-project
      Description: A build project for !Ref ApplicationName
      ServiceRole: !Ref BuildProjectRole
      Artifacts:
        Type: CODEPIPELINE
        Packaging: ZIP
      Environment:
        Type: LINUX_CONTAINER
        ComputeType: BUILD_GENERAL1_SMALL
        Image: aws/codebuild/amazonlinux2-x86_64-standard:3.0
      Source:
        Type: CODEPIPELINE
        BuildSpec: |
          version: 0.2
          phases:
            build:
              commands:
                - echo "hello world"

```

Nous rajoutons:
- 2 paramètres:
  - `GithubRepo`: le nom du repo `Github
  - `GithubRepoBranch`: la branche à récupérer, par défaut: `main`
- un projet `CodeBuild`
- la permission au rôle `CodePipeline` de déclencher le projet `CodeBuild` défini just après

On aurait pu définir les paramètres et l'extension des permissions du projet `CodePipeline` lors d'un futur commit, mais bon, ce qui est fait est fait, ça sera pour un futur article encore plus clean.

updatons la stack `CloudFormation` via le script helper:
```shell
./create-all.sh my-app
```

On vérifie la bonne éxécution de la mise à jour de la stack, ainsi que la création de la nouvelle ressource:
![](images/6.1-codebuild-project.png)

On jette un oeil aux projets CodeBuild pour vérifier la création du projet:
![](images/6.2-codebuild-project.png)

On fait confiance à `CloudFormation` pour avoir mis à jour les permission IAM sur le rôle dédié à `CodePipeline`.

Pour le sport, on peut vérifier l'apparition des 2 nouvelles properties:
![](images/6.3-codebuild-project.png)

### <a name="1.7-codepipeline-project"></a> 6. Mise en place d'un projet CodePipeline
tag de départ: `1.6-codebuild-project`
tag d'arrivée: `1.7-codepipeline-project`

Dans cette partie, nous allons rajouter un projet `CodePipeline`, qui sera composé de 2 stages:
- "Source", pour récupérer le code source depuis le repo `Github`
- "Build", qui va builder le projet java. Pour cette étape cependant, nous allons juste afficher "hello world" dans la console, pour vérifier le déclenchement du projet `CodeBuild` par `CodePipeline`

Ce qui se traduit par l'ajout de la ressource `CloudFormation` suivante:

```yaml
Pipeline:
  Description: Creating a deployment pipeline for !Ref ApplicationName project in AWS CodePipeline
  Type: 'AWS::CodePipeline::Pipeline'
  Properties:
    RoleArn: !GetAtt
      - PipelineRole
      - Arn
    ArtifactStore:
      Type: S3
      Location: !Ref S3Bucket
    Stages:
      - Name: Source
        Actions:
          - Name: Source
            ActionTypeId:
              Category: Source
              Owner: AWS
              Version: 1
              Provider: CodeStarSourceConnection
            OutputArtifacts:
              - Name: SourceOutput
            Configuration:
              ConnectionArn: !Ref GithubConnection
              FullRepositoryId: !Ref GithubRepo
              BranchName: !Ref GithubRepoBranch
              OutputArtifactFormat: "CODE_ZIP"
      - Name: Build
        Actions:
          - Name: Build
            InputArtifacts:
              - Name: SourceOutput
            OutputArtifacts:
              - Name: BuildOutput
            ActionTypeId:
              Category: Build
              Owner: AWS
              Version: 1
              Provider: CodeBuild
            Configuration:
              ProjectName:
                Ref: BuildProject
```

Voir [https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-resource-codepipeline-pipeline.html](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-resource-codepipeline-pipeline.html) pour la documentation

Analysons un peu cette ressource:
![](images/7.1-codepipeline-project.png)

1. Le projet `CodePipeline` s'éxécutera avec le rôle définit dans l'étape #4
2. Les artefacts générés par la pipeline seront stockés dans le bucket S3 défini dans l'étape #1
3. Stage "Source"
  - 3.1 Le stage "Source" est composé d'une seule Action, de catégorie "Source", dont le provider est `CodeStarSourceConnection`. 
    - Voir [https://docs.aws.amazon.com/codepipeline/latest/userguide/reference-pipeline-structure.html#actions-valid-providers](https://docs.aws.amazon.com/codepipeline/latest/userguide/reference-pipeline-structure.html#actions-valid-providers) pour la liste des types d'action valides, et les différents provider pour chaque type
  - 3.2 On donne le nom "SourceOutput" pour la sortie de l'action associé au stage "Source". Cela définira le nom d'un dossier dans le bucket S3 associé à la pipeline
- 3.3 La configuration de l'action de type `CodeStarSourceConnection`
    - Voir [https://docs.aws.amazon.com/codepipeline/latest/userguide/action-reference-CodestarConnectionSource.html](https://docs.aws.amazon.com/codepipeline/latest/userguide/action-reference-CodestarConnectionSource.html) pour la référence de la configuration pour les actions de type `CodeStarSourceConnection`

![](images/7.2-codepipeline-project.png)
4. Stage "Build"
  - 4.1 L'action de build prend en entrée "SourceOutput"
  - 4.2 L'action de build a pour sortie "BuildOutput"
  - 4.3 L'action est de catégorie "Build" et a pour provider `CodeBuild`. Dans la configuration, on référence le projet `CodeBuild` créé dans l'étape #5

updatons la stack `CloudFormation` via le script helper:
```shell
./create-all.sh my-app
```

On vérifie la bonne éxécution de la mise à jour de la stack, ainsi que la création de la nouvelle ressource:
![](images/8.1-codepipeline-project.png)

On vérifie la création et le statut de la pipeline dans "Developer Tools":
![](images/8.2-codepipeline-project.png)

Si le statut est en échec, cela peut venir du fait que la connexion github n'est pas activée.
Nous l'avons fait lors de l'étape #2, mais si jamais vous avez par exemple, supprimé et recréé la stack `CloudFormation` de la pipeline vous devrez activer à nouveau la connexion et relancer une release dans la pipeline:
![](images/3.1-github-connection.png)

La pipeline devrait alors s'être éxécutée avec succès:
![](images/8.3-codepipeline-project.png)

Allons inspecter le résultat du build
![](images/8.4-codepipeline-project.png)

Vérifions la console:
![](images/8.5-codepipeline-project.png)

Nous avons bien pu logger "Hello World". Allons inspecter enfin le code source dans le bucket S3:
![](images/8.6-codepipeline-project.png)

On note les répertoires créés par `CodePipeline` et le lien avec les configurations  "InputArtifacts" et "OutputArtifacts" du template `CloudFormation` de notre pipeline.

Téléchargeons le zip et inspectons son contenu:
![](images/8.7-codepipeline-project.png)

Le contenu du zip est bien le code source du projet. Félicitations, nous avons désormais une base réutilisable et assez générique, pour bootstrapper une pipeline de CI/CD.

### <a name="1.8-buildtime-test-junit-execution-local"></a> 7. Mise en place d'un projet Java avec éxécution d'un test unitaire "build time" en Junit - local
tag de départ: `1.7-codepipeline-project`
tag d'arrivée: `1.8-buildtime-test-junit-execution-local`

Dans cette étape, nous créons un projet `Java` minimal, avec juste le nécessaire pour éxécuter un test unitaire:

fichier `pom.xml`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <groupId>org.example</groupId>
    <artifactId>codebuild-test-report-demo</artifactId>
    <version>1.0-SNAPSHOT</version>

    <properties>
        <maven.compiler.source>11</maven.compiler.source>
        <maven.compiler.target>11</maven.compiler.target>

        <junit-jupiter.version>5.7.2</junit-jupiter.version>
        <assertj.version>3.19.0</assertj.version>

        <maven-surefire-failsafe-plugin.version>3.0.0-M5</maven-surefire-failsafe-plugin.version>
    </properties>

    <dependencies>
        <dependency>
            <groupId>org.junit.jupiter</groupId>
            <artifactId>junit-jupiter</artifactId>
            <version>${junit-jupiter.version}</version>
            <scope>test</scope>
        </dependency>
        <dependency>
            <groupId>org.assertj</groupId>
            <artifactId>assertj-core</artifactId>
            <version>${assertj.version}</version>
            <scope>test</scope>
        </dependency>
    </dependencies>

    <build>
        <plugins>
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-surefire-plugin</artifactId>
                <version>${maven-surefire-failsafe-plugin.version}</version>
            </plugin>
        </plugins>
    </build>

</project>
```
Nous ajoutons:
- une dépendance vers junit-5
- une dépendance vers assertj (l'auteur effectue les assertions via cette librairie plutôt que Junit)
- le plugin `surefire`, afin que les tests junit-5 soient lancés quand on éxécute: `mvn test`

Nous pouvons ainsi lancer des tests unitaires `Junit`:
- via l'IDE:
![](images/9.1-buildtime-test-junit-local.png)
  
- via la CLI:
![](images/9.2-buildtime-test-junit-local.png)

### <a name="1.9-buildtime-test-junit-reporting-local"></a> 8. Mise en place de la couverture de test avec Jacoco - local
tag de départ: `1.8-buildtime-test-junit-execution-local`
tag d'arrivée: `1.9-buildtime-test-junit-reporting-local`

Dans cette étape, nous allons rajouter le reporting de couverture de test: 

Pour cela nous effectuons les actions suivantes: 
- rajouter un plugin `Maven` du nom de `Jacoco` ("JAva COde COverage")
- rajouter une classe de prod (dans `src/main/java`) avec une méthode quelconque, et couvrir cette méthode par un test. Sans classe de prod, le rapport de couverture est vide

rajouts dans le `pom.xml`:
```xml

<properties>
    [...]
    <jacoco.version>0.8.7</jacoco.version>
</properties>

<build>
    <plugins>
        [...]
        <plugin>
            <groupId>org.jacoco</groupId>
            <artifactId>jacoco-maven-plugin</artifactId>
            <version>${jacoco.version}</version>
            <executions>
                <execution>
                    <id>jacoco-prepare-agent</id>
                    <goals>
                        <goal>prepare-agent</goal>
                    </goals>
                </execution>
                <execution>
                    <id>jacoco-coverage-report</id>
                    <phase>test</phase>
                    <goals>
                        <goal>report</goal>
                    </goals>
                </execution>
            </executions>
        </plugin>
    </plugins>
</build>
```

Analysons un peu la configuration de ce plugin:
![](images/10.1-buildtime-test-junit-reporting-local.png)

1. On définit une éxécution pour "préparer l'agent jacoco"
  - 1.1 On donne l'id "jacoco-prepare-agent", ce qui apparaitra aussi dans les logs. Autrement, l'id est "default", et on ne peut avoir avoir 2 éxécutions avec le même id
  - 1.2 On éxécute le goal `prepare-agent` du plugin. Ce goal est par défaut bindé à la phase `initialize` du lifecycle `default` de `Maven`
2. On définit une éxécution pour créer le rapport de couverture
  - 2.1 On donne l'id "jacoco-coverage-report" à cette éxécution
  - 2.2 On éxécute le goal `report` du plugin. On redéfinit le binding de ce goal à la phase `test` du lifecycle de `Maven` car par défaut il est bindé à la phase `verify`, et on voulait pouvoir avoir les rapport d'éxécution des tests unitaires lors d'un `mvn test`. Même si concrètement, le binding par défaut est très bien, on n'a pas vraiment de cas où l'on souhaite les rapports de couverture de test sans avoir le `.jar`, mais bon.

Après avoir éxécuté `mvn clean test`, les rapports de couverture sont disponibles dans `target/site/jacoco/`, sous différents formats.

Jetons un oeil au `.html` généré:

![](images/10.2-buildtime-test-junit-reporting-local.png)


Voici un ensemble de références intéressantes pour `Jacoco`, sur la configuration de plugins `Maven`, ou encore sur les cycles de vie de ce dernier, et les différences entre cycle de vie, phase et goal:
- [https://www.eclemma.org/jacoco/trunk/doc/maven.html ](https://www.eclemma.org/jacoco/trunk/doc/maven.html )
- [https://www.eclemma.org/jacoco/trunk/doc/prepare-agent-mojo.html](https://www.eclemma.org/jacoco/trunk/doc/prepare-agent-mojo.html)
- [https://www.eclemma.org/jacoco/trunk/doc/report-mojo.html](https://www.eclemma.org/jacoco/trunk/doc/report-mojo.html)
- [https://www.baeldung.com/jacoco](https://www.baeldung.com/jacoco)
- [https://maven.apache.org/guides/introduction/introduction-to-the-lifecycle.html#Lifecycle_Reference](https://maven.apache.org/guides/introduction/introduction-to-the-lifecycle.html#Lifecycle_Reference)
- [https://maven.apache.org/guides/mini/guide-configuring-plugins.html](https://maven.apache.org/guides/mini/guide-configuring-plugins.html)

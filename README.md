# CodeBuild test report demo

:fr: Sommaire / :gb: Table of Contents
=================

<!--ts-->

- [:fr: Description du projet](#fr-description-du-projet)
- [:gb: Project Description](#gb-project-description)
  
---

# :fr: Description du projet

Le but de ce projet et de servir de démo et de support pour l'intégration de rapport de tests à une pipeline de cicd dans AWS Developer Tools (CodeBuild, CodeDeploy, CodePipeline, etc.) pour une application java backend basique.

Les types de tests que nous couvrirons seront:
- tests lors du build de l'application
  - tests unitaires: `mvn test` 
  - tests "d'intégration": `mvn verify`
- tests sur l'application déployée dans un environnement, instance-s EC2 pour notre démo
  - des tests en Java / Cucumber, déclenchés via `Maven`

# :gb: Project Description

The goal of this project is to demonstrate and be used as a future reference for integrating test reports to a cicd pipeline using AWS Developer Tools (CodeBuild, CodeDeploy, CodePipeline, etc.) for a basic java backend application.

The types of tests we will cover are:
- "build time" tests
  - unit tests: `mvn test`
  - so-called "integration tests": `mvn verify`
- tests on the application being deployed in an environment, EC2 instances in that case
  - Java / Cucumber tests, launched with `Maven`

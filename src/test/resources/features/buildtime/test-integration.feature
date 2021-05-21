@integrationTest
Feature: build time integration feature
  Scenario: build time integration test scenario
    When we call `MyClassCucumberIT.helloCucumberIT` method
    Then the `MyClassCucumberIT.helloCucumberIT` response is "helloCucumberIT"
Feature: API test

  Scenario: API returns expected response
    When we call the REST endpoint "/"
    Then the REST response is as following:
      | httpStatus | 200           |
      | body       | "hello world" |
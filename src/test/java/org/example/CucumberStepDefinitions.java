package org.example;

import io.cucumber.java.en.Given;
import io.cucumber.java.en.Then;
import io.cucumber.java.en.When;
import org.assertj.core.api.Assertions;

import static org.assertj.core.api.Assertions.assertThat;

public class CucumberStepDefinitions {

  private String holaResponse;

  @When("we call `MyOtherClass.hola` method")
  public void whenWeCallOtherClassHola() {
    holaResponse = new MyOtherClass().hola();
  }

  @Then("the response is {string}")
  public void theResponseIs(String expectedResponse) {
    assertThat(holaResponse).isEqualTo(expectedResponse);
  }
}

package org.example;

import io.cucumber.java.en.Then;
import io.cucumber.java.en.When;

import static org.assertj.core.api.Assertions.assertThat;

public class CucumberStepDefinitionsIT {

  private String holaResponse;

  @When("we call `MyClassCucumberIT.helloCucumberIT` method")
  public void whenWeCallOtherClassHola() {
    holaResponse = new MyClassCucumberIT().helloCucumberIT();
  }

  @Then("the `MyClassCucumberIT.helloCucumberIT` response is {string}")
  public void theResponseIs(String expectedResponse) {
    assertThat(holaResponse).isEqualTo(expectedResponse);
  }
}

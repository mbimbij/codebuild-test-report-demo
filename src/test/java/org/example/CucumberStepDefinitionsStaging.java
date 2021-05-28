package org.example;

import io.cucumber.java.en.Then;
import io.cucumber.java.en.When;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.client.RestTemplate;

import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

@Slf4j
public class CucumberStepDefinitionsStaging {

  private ResponseEntity<String> responseEntity;

  @When("we call the REST endpoint {string}")
  public void weCallTheRESTEndpoint(String endpoint) {
    String restEndpointUrl = buildEndpointUrl();
    log.info("calling url: \"{}\"",restEndpointUrl);
    responseEntity = new RestTemplate().getForEntity(restEndpointUrl, String.class);
  }

  private String buildEndpointUrl() {
    String restEndpointHostname = System.getenv("REST_ENDPOINT_HOSTNAME");
    String restEndpointProtocol = System.getenv("REST_ENDPOINT_PROTOCOL");
    String restEndpointPort = System.getenv("REST_ENDPOINT_PORT");
    return restEndpointProtocol+"://"+restEndpointHostname+":"+restEndpointPort;
  }

  @Then("the REST response is as following:")
  public void theRESTResponseIsAsFollowing(Map<String, String> expectedValues) {
    assertThat(responseEntity.getStatusCodeValue()).isEqualTo(200);
    assertThat(responseEntity.getBody()).isEqualTo(MyRestController.RESPONSE);
  }
}

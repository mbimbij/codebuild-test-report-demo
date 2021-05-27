package org.example;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.http.ResponseEntity;

import static org.assertj.core.api.Assertions.assertThat;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class MySpringApplicationIT {

  @Autowired
  private TestRestTemplate restTemplate;

  @Test
  void canCallRestResourceRoot() {
    // WHEN
    ResponseEntity<String> responseEntity = restTemplate.getForEntity("/", String.class);

    // THEN
    assertThat(responseEntity.getStatusCodeValue()).isEqualTo(200);
    assertThat(responseEntity.getBody()).isEqualTo(MyRestController.RESPONSE);
  }
}

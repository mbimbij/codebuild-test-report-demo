package org.example;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class MyRestController {

  public static final String RESPONSE = "hello world";

  @GetMapping("/")
  public String get() {
    return RESPONSE;
  }

}

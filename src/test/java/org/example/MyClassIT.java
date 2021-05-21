package org.example;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class MyClassIT {
  @Test
  void test() {
    MyClass myClass = new MyClass();
    assertThat(myClass.integrationHello()).isEqualTo("integrationHello");
  }

}

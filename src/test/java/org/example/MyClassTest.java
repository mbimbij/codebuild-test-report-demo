package org.example;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class MyClassTest {
  @Test
  void test() {
    MyClass myClass = new MyClass();
    assertThat(myClass.hello()).isEqualTo("hello");
  }

}

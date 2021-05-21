package org.example;

import io.cucumber.junit.Cucumber;
import io.cucumber.junit.CucumberOptions;
import org.junit.runner.RunWith;

@RunWith(Cucumber.class)
@CucumberOptions(
    plugin = {
        "pretty",
        "junit:target/cucumber-reports/buildtime/cucumber-results.xml",
        "usage:target/cucumber-reports/buildtime/cucumber-usage.json"},
    glue = {"org.example"},
    features = "src/test/resources/features/buildtime")
public class CucumberRunnerTest {
}

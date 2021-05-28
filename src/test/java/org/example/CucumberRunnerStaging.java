package org.example;

import io.cucumber.junit.Cucumber;
import io.cucumber.junit.CucumberOptions;
import org.junit.runner.RunWith;
import org.springframework.boot.test.context.SpringBootTest;

import static org.springframework.boot.test.context.SpringBootTest.WebEnvironment.RANDOM_PORT;

@SpringBootTest(webEnvironment = RANDOM_PORT)
@RunWith(Cucumber.class)
@CucumberOptions(
    plugin = {
        "pretty",
        "junit:target/cucumber-reports/staging/cucumber-staging-results.xml",
        "usage:target/cucumber-reports/staging/cucumber-staging-usage.json"},
    glue = {"org.example"},
    features = "src/test/resources/features/staging")
public class CucumberRunnerStaging {
}

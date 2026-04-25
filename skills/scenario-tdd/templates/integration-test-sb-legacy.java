package <PACKAGE>;

import io.restassured.RestAssured;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;

import static io.restassured.RestAssured.given;

// Spring Boot < 3.1 integration-test scaffolding.
// Service runs in a container started by `<runtime> compose -f docker-compose.test.yml up -d`
// before mvn test. One @Test per scenario; method name = camelCase(scenario id) — must
// match the test_method_name field emitted by `scenarios gap --run`.
class <DOMAIN>IntegrationTest {

    static final String BASE_URI =
        System.getenv().getOrDefault("SERVICE_BASE_URI", "http://localhost:8080");

    @BeforeAll
    static void setup() {
        RestAssured.baseURI = BASE_URI;
    }

    @Test
    void happyPath() {
        given()
            .contentType("application/json")
            .body("{ ... }")
        .when()
            .post("/<endpoint>")
        .then()
            .statusCode(201);
    }
}

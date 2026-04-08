# Java Coding Standards

These rules apply to all Java code written in this project. Loaded by `java-tdd` and `contract-testing` skills.

## Naming

- Classes: `PascalCase`
- Methods and fields: `camelCase`
- Constants: `UPPER_SNAKE_CASE`
- Packages: `lowercase.with.dots`
- Test classes: suffix with `Test` (unit) or `IntegrationTest` (integration)
- Test methods: `methodName_scenarioDescription` (e.g. `createInvoice_withValidData_returns201`)

## Code Structure

- One public class per file
- Controllers in `api/` package: only request mapping, input validation, response mapping. No business logic.
- Services in `service/` or domain package: business logic only. No HTTP concerns.
- Repositories in `repository/` package: data access only.
- DTOs/request/response objects: immutable where possible, use records for Java 16+.

## Spring Boot

- Use constructor injection (not `@Autowired` on fields)
- Validate request bodies with `@Valid` and Jakarta Bean Validation annotations
- Use `@RestControllerAdvice` for global exception handling
- Return `ResponseEntity<T>` from controllers
- Use `@Transactional` at the service layer, not the controller layer

## Testing

- Unit tests: mock all dependencies with Mockito
- Integration tests (`*IntegrationTest`): use real infrastructure (Testcontainers or docker-compose)
- Test one behavior per test method
- Use `@BeforeEach` for setup, `@AfterEach` for cleanup
- Assert on behavior, not implementation details
- Do NOT test private methods directly — test through public API

## Error Handling

- Use custom exception classes extending `RuntimeException` for domain errors
- Map exceptions to HTTP status codes in `@RestControllerAdvice`
- Return RFC 7807 problem details format for error responses:
  ```json
  {
    "type": "https://example.com/problems/not-found",
    "title": "Resource not found",
    "status": 404,
    "detail": "Invoice 123 not found"
  }
  ```

## Database / JPA

- Use `UUID` primary keys (not auto-increment Long)
- Annotate entities with `@Entity`, repositories with `@Repository`
- Use Flyway for database migrations (files in `src/main/resources/db/migration/`)
- Migration naming: `V<YYYYMMDD>_NNN__<description>.sql`
- Do NOT use `@GeneratedValue(strategy = AUTO)` — use `@GeneratedValue(generator = "UUID")` or assign in constructor

## Logging

- Use SLF4J (`private static final Logger log = LoggerFactory.getLogger(MyClass.class)`)
- Log at INFO for significant business events
- Log at DEBUG for internal state (disabled in production)
- Never log passwords, tokens, or PII

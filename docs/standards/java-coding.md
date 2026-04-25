# Java Coding Standards

**Applies always.**

## Technology Stack

Stack values are sourced from `project-info.yaml > stack`. Default versions:

- Language: Java (`stack.java`, default `17`; runtime: amazon-corretto-17)
- Framework: Spring Boot (`stack.spring-boot`, default `3.3.13`)
- ORM: MyBatis-Plus (`stack.mybatis-plus`, default `3.5.6`; artifact `mybatis-plus-spring-boot3-starter`)
- Build: Maven
- Testing: JUnit 5
- Format: Spotless
- Logging: SLF4J + Logback

## Package & Port

- Package: `project-info.yaml > project.package` (default: `com.newland.{project.name}`)
- Server port: `project-info.yaml > project.server-port` (if absent: random integer in 3000–3999)

## Layered Architecture

- Layers: Controller → Service → Repository
- Controller MUST NOT access Repository directly
- All dependencies MUST be injected via Spring IoC; no manual `new`
- Use constructor injection (not `@Autowired` on fields)

## Method Constraints

- Method length < 50 lines
- Max nesting depth = 3
- Single responsibility per method

## One Class Per File

- Each `.java` file MUST contain at most one public class.

## Comment Standards

### Standards
- ALL public classes and methods MUST have Javadoc
- Comments MUST explain "what" and "why"; MUST NOT restate code logic
- Every public method Javadoc MUST include `@param`, `@return`, and `@throws` tags where applicable

| Layer      | Class Javadoc                       | Method Javadoc                          |
|------------|-------------------------------------|-----------------------------------------|
| Controller | API purpose + business context      | description, params, return             |
| Service    | Business domain description         | core logic, key processing              |
| Repository | Data access responsibility          | query purpose, key conditions           |
| Entity     | Table/domain description            | field meaning, enum values              |

Inline comments required for: complex logic, business rules, edge case handling.

Forbidden: empty comments, commented-out code, redundant comments that restate what code says.

### Checks
- [ ] Every public class has Javadoc
- [ ] Every public method has Javadoc with `@param`/`@return`/`@throws` where applicable
- [ ] No empty Javadoc blocks (`/** */`)
- [ ] No commented-out code blocks

### Key Generation Step Comments

During code generation, the following key steps MUST include comment descriptions:

- **Entity class**: Comments must state the corresponding database table name, field meaning, and business meaning
- **DAO/Mapper interface**: Comments must state the data access responsibility and key query conditions
- **Service implementation class**: Comments must state the core business logic, processing flow, and key branch decisions
- **Controller interface**: Comments must state the API purpose, request parameter meaning, and return value meaning
- **Complex business logic blocks**: Must use inline comments to clarify business rules, boundary conditions, and data transformation logic
- **Transaction boundaries**: Transaction methods must document `@Transactional` and transaction propagation behavior in Javadoc

---

## Large Data Handling Rules

### Pagination Queries

- Pagination is MANDATORY when querying large datasets; do NOT load full results into a `List`
- When joining related tables, evaluate data volume to avoid Cartesian products causing OOM
- Use MyBatis-Plus `Page` for pagination.

### Import / Export

- Large file import/export (e.g. Excel) must use batch processing; do NOT load entire file into memory at once
- Recommended batch size: ~1000 rows per batch to prevent `OutOfMemoryError`
- Export: use streaming write (`SXSSFWorkbook` or EasyExcel streaming API)
- Import: use EasyExcel `AnalysisEventListener` for row-by-row processing

---

## Spring Configuration

- `application.yml`: common/shared settings only
- `application-{env}.yml`: environment-specific settings
- `.env.dev` present → create `application-dev.yml`
- `.env.test` present → create `application-test.yml`
- Profile activation controlled via `spring.profiles.active`
- No env-specific values in `application.yml`; no duplication across files

## Externalizing Configurable Values

Any value that is public, business-meaningful, or likely to change across environments MUST be placed in `application-{env}.yml` and injected via `@Value` or `@ConfigurationProperties`. NEVER hardcode such values directly in Java source code.

**Applies to (non-exhaustive):**
- Scheduled task cron expressions (e.g. `@Scheduled(cron = ...)`)
- Timeouts, retry counts, batch sizes, thresholds
- File paths, URL prefixes, bucket names
- Feature toggles or business rule constants

**Correct pattern:**

```yaml
# application-dev.yml
scheduler:
  template-cleanup:
    cron: "0 0 2 * * *"
```

```java
// Java
@Scheduled(cron = "${scheduler.template-cleanup.cron}")
public void cleanupExpiredTemplates() { ... }
```

### Checks
- [ ] No `@Scheduled(cron = "<literal>")` in source — must use `${prop}` placeholder
- [ ] No hardcoded timeout/retry/batch-size/threshold literals in Java source
- [ ] No hardcoded URL prefixes, file paths, or bucket names in Java source

## Logging Configuration Rules

### Logger Declaration

- Use `@Slf4j` (Lombok) annotation on each class that requires logging
- Never use `System.out.println` or `System.err.println`

### Log Content Rules

- Always log the exception object as the last argument (not just the message)
- Never log sensitive data: passwords, tokens, PII, card numbers
- Include enough context to reproduce the issue (entity IDs, operation type)

### Logback Configuration

The project must define logging behavior in `logback-spring.xml` (not `logback.xml`).

Required configuration:

- Console appender for local/dev
- Rolling file appender for test/prod
- Log file path must be configurable via environment variable (e.g., `LOG_PATH`)
- Rolling policy: daily rollover, compressed storage when a single file exceeds 100M, max 30 days retention, max 10 GB total size
- Archive log save directory: `{yyyy}/{MM}/{dd}/{project-name}.%d{yyyy-MM-dd}.log.%i.gz` (gz-compressed)
- The log file name defaults to the project name
- Pattern must include: timestamp, level, thread, logger, message

```xml
<!-- Minimum required pattern -->
%d{yyyy-MM-dd HH:mm:ss.SSS} [%thread] %-5level %logger{36} - %msg%n
```

### Log Level per Environment

Environment-specific log levels must be set in the corresponding `application-xx.yml`:

```yaml
logging:
  level:
    root: INFO
    com.newland: DEBUG   # lower for dev; INFO or WARN for prod
```

- `dev`: `com.newland` → `DEBUG`
- `test`: `com.newland` → `INFO`
- Production-like environments: `root` → `WARN`, `com.newland` → `INFO`

### Checks
- [ ] `@Slf4j` annotation present on every class that logs (no manual `LoggerFactory.getLogger`)
- [ ] No `System.out` / `System.err` calls in `src/`
- [ ] `logback-spring.xml` exists; `logback.xml` does not
- [ ] Log file path uses an env variable (e.g. `${LOG_PATH}`)
- [ ] Rolling policy: daily, gz on >100MB, 30-day retention, 10 GB total
- [ ] Log pattern includes timestamp, level, thread, logger, message

## DAO Model Rules

DAO/MyBatis-Plus rules → see [`database.md`](database.md).

## Maven Repositories

Every generated `pom.xml` MUST include a `<repositories>` block whose entries come from `project-info.yaml > maven.repositories`. Apply each entry verbatim.

**Placement:** inside `<project>`, after `</dependencies>` and before `<build>`.

Example output (using the shipped template defaults):

```xml
<repositories>
    <repository>
        <id>aliyun-repos</id>
        <url>https://maven.aliyun.com/repository/public</url>
        <snapshots><enabled>false</enabled></snapshots>
    </repository>
    <repository>
        <id>maven-snapshots</id>
        <url>http://192.168.132.145:54002/nexus/repository/maven-snapshots/</url>
    </repository>
</repositories>
```

This applies to both new projects and existing `pom.xml` files that are missing this block.

---

## Maven Commands

```
mvn spotless:apply         # fix formatting
mvn clean install          # build + spotless + tests
mvn test                   # run all tests
mvn spring-boot:run        # start application
```

## Testing

- Test class naming: suffix with `Test` (unit) or `IntegrationTest` (integration)
- Test method naming: `methodName_scenarioDescription` (e.g., `createInvoice_withValidData_returns201`)
- Unit tests: mock all dependencies with Mockito
- Integration tests (`*IntegrationTest`): use real infrastructure (Testcontainers or docker-compose)
- Test one behavior per test method
- Use `@BeforeEach` for setup, `@AfterEach` for cleanup
- Assert on behavior, not implementation details
- Do NOT test private methods directly — test through public API

# Spring Cloud Standards

**Applies when:** `spring-cloud.enabled: true` in `project-info.yaml`. Each sub-module additionally checks its own `enabled` flag. If the top-level `spring-cloud.enabled` is `false`, all sub-modules are skipped regardless of their own settings.

---

## Env File Convention

Server addresses are NOT stored in `project-info.yaml`. They are read from `.env.{env}.{component}` files in the project root, where `{env}` follows the detection priority defined in [`environment.md`](environment.md) (`dev` → `test` → `inte`) and `{component}` is the lowercase component selected by `project-info.yaml > spring-cloud.{module}.component`.

This file owns the **variable name table** per component:

| Component  | File pattern              | Variables                                              |
|------------|---------------------------|--------------------------------------------------------|
| nacos      | `.env.{env}.nacos`        | `NACOS_SERVER_ADDR`, `NACOS_NAMESPACE`, `NACOS_GROUP`  |
| eureka     | `.env.{env}.eureka`       | `EUREKA_DEFAULT_ZONE`                                  |
| consul     | `.env.{env}.consul`       | `CONSUL_HOST`, `CONSUL_PORT`                           |
| zookeeper  | `.env.{env}.zookeeper`    | `ZOOKEEPER_CONNECT_STRING`                             |
| sentinel   | `.env.{env}.sentinel`     | `SENTINEL_DASHBOARD_ADDR`                              |

If the env file is missing: ask the user (per `environment.md`); if the user does not supply one, fall back to `project-info.yaml > spring-cloud.{module}.default-address` if present.

---

## Module: Discovery (Required when top-level enabled)

Discovery has no `enabled` flag — it is always required when Spring Cloud is enabled.

1. Read `component` from `project-info.yaml > spring-cloud.discovery.component`.
2. If `component` is blank, ask the user before proceeding.
3. Locate `.env.{env}.{component}` per the Env File Convention above.
4. Read the component's server variable(s) from that file.

**Standards:**
- Discovery configuration MUST be written to `bootstrap.yml`
- Server address MUST NOT be hardcoded — use the env variable as a Spring property placeholder, e.g. `${NACOS_SERVER_ADDR}`
- Add the component-specific Spring Cloud starter dependency to `pom.xml`
- This project uses Spring Boot 3.x. `bootstrap.yml` is NOT loaded by default — add `spring-cloud-starter-bootstrap` to `pom.xml` to enable it, OR use `spring.config.import` in `application.yml` instead
- Use Spring Cloud BOM `2023.0.x` (compatible with Spring Boot 3.3.x): add `spring-cloud-dependencies` to `<dependencyManagement>` in `pom.xml`

---

## Module: Config Center

**Applies when:** `spring-cloud.config-center.enabled: true`.

1. Read `component` from `project-info.yaml > spring-cloud.config-center.component`.
2. Locate `.env.{env}.{component}` (same file as Discovery when both use the same component).
3. Read server address and, for nacos, also `NACOS_NAMESPACE` and `NACOS_GROUP`.

**Standards:**
- Config Center configuration MUST be written to `bootstrap.yml`
- `NACOS_NAMESPACE` and `NACOS_GROUP` defaults if env var is blank:
  - namespace → `""` (public namespace)
  - group → `DEFAULT_GROUP`
- `spring-cloud-config`: no namespace/group concept; use `spring.cloud.config.uri=${SPRING_CONFIG_URI}`
- Server address MUST NOT be hardcoded

---

## Module: Circuit Breaker

**Applies when:** `spring-cloud.circuit-breaker.enabled: true`.

1. Read `component` from `project-info.yaml > spring-cloud.circuit-breaker.component` (`sentinel` or `resilience4j`).
2. Sentinel only: locate `.env.{env}.sentinel`, read `SENTINEL_DASHBOARD_ADDR`.

**Standards:**
- Apply `@SentinelResource` (sentinel) or `@CircuitBreaker` (resilience4j) on all Feign client methods that call other services
- Every circuit-breaker annotated method MUST have a fallback method defined
- Sentinel: configure `spring.cloud.sentinel.transport.dashboard=${SENTINEL_DASHBOARD_ADDR}` in `application.yml`; MUST NOT be hardcoded
- Resilience4j: define instances in `application.yml` under `resilience4j.circuitbreaker.instances`

---

## Module: Gateway

**Applies when:** `spring-cloud.gateway.enabled: true`.

**Standards (development decisions — no config file generated):**
- If gateway is present, do NOT implement authentication in this microservice — delegate to the gateway (see also [`auth-toms.md`](auth-toms.md) gating)
- Trust gateway-forwarded headers (e.g., `X-User-Id`, `X-Tenant-Id`) instead of re-validating tokens
- Do not expose service port directly in API docs — document gateway-facing paths

---

## Checks

### Discovery
- [ ] `bootstrap.yml` contains service discovery registration config
- [ ] Server address uses `${ENV_VAR}` placeholder, not a hardcoded value
- [ ] Component starter dependency present in `pom.xml`

### Config Center
- [ ] `bootstrap.yml` contains config-center pull configuration
- [ ] `namespace` and `group` are explicitly set (or defaulted with a comment)
- [ ] Server address uses `${ENV_VAR}` placeholder

### Circuit Breaker
- [ ] All Feign client methods have circuit-breaker annotation
- [ ] Every annotated method has a fallback method
- [ ] Sentinel: dashboard address uses `${SENTINEL_DASHBOARD_ADDR}` placeholder
- [ ] Resilience4j: circuit-breaker instances defined in `application.yml`

### Gateway
- [ ] No JWT / token validation logic in this service if gateway handles auth
- [ ] Forwarded identity headers are trusted where used

# Java Coding Standards Refactor

**Status:** Draft
**Date:** 2026-04-25

## Background

The current `docs/java-coding-standards.md` is a single generic Spring Boot guide (JPA, RFC 7807, plain SLF4J). It is loaded as "Step 0" by the `java-tdd`, `java-verify`, and `scenario-tdd` skills, and is referenced by their corresponding specs and plans under `docs/superpowers/`.

In parallel, the team maintains a richer, stack-specific ruleset in another repository (`/workspaces/claude-plugin-java/`) split across:

- `skills/generate/reference/` — `java-coding-rule.md`, `api-rule.md`, `exception-rule.md`, `i18n-rule.md`, `redis-rule.md`, `spring-cloud-rule.md`, `toms-authorization-rule.md`
- `rules/environment-rule.md`
- `skills/db-schema/reference/mysql-rule.md`, `tenant-rule.md`

These rules target the team's actual stack: Java 17 (corretto), Spring Boot 3.3.13, MyBatis-Plus 3.5.6, `com.newland.*` packaging, MySQL with `t_*` tables and `character_code`/`key_id` multi-tenancy, TOMS authorization, optional Spring Cloud (nacos/eureka/consul/zookeeper/sentinel).

The current generic doc materially conflicts with this stack (JPA vs MyBatis-Plus, RFC 7807 envelope vs `{code,message,data}` error format, plain SLF4J vs `@Slf4j`, generic packaging vs `com.newland.*`). This refactor replaces the generic doc with the team's rules, adopting them as jkit's first-class Java standards. Stack-specific concepts (Spring Cloud, TOMS, i18n, Redis, multi-tenancy) gate themselves against per-project configuration so jkit projects that don't use them aren't burdened with their rules.

## Goals

1. Replace the generic `docs/java-coding-standards.md` with a split, multi-file ruleset under `docs/standards/`.
2. Introduce `docs/project-info.yaml` as a per-project config that drives which conditional rules apply, with a shipped template at `docs/project-info.schema.yaml`.
3. Add a `jkit standards list` CLI subcommand so skills load only the applicable files.
4. Reconcile internal contradictions, strengthen "Checks" sections, normalize applicability headers, and extract environment-specific values (internal nexus URL, TOMS api-version) out of standards prose into `project-info.yaml`.

## Non-Goals

- Authoring rules for technology not represented in the source rule files (e.g., JPA, Postgres, Kafka). Out of scope.
- Designing a `docs/domains/*/api-implement-logic.md` format. The TOMS rule references it as a project artifact; defining its format is a separate effort.
- JSON Schema validation of `project-info.yaml`. The commented YAML template is the authoritative schema for now; a JSON Schema can be added later if needed.
- Backwards compatibility with the existing generic doc. Skills will be updated; old references will be migrated mechanically.

## File Layout

```
docs/
├── java-coding-standards.md          # Index — applicability table + links. Skills already cite this path.
├── project-info.schema.yaml          # Shipped commented template / canonical defaults
└── standards/
    ├── java-coding.md                # Always
    ├── api.md                        # Always
    ├── exception.md                  # Always
    ├── environment.md                # Always
    ├── database.md                   # Conditional: database.enabled (default true)
    ├── tenant.md                     # Conditional: tenant.enabled
    ├── i18n.md                       # Conditional: i18n.enabled
    ├── redis.md                      # Conditional: redis.enabled
    ├── spring-cloud.md               # Conditional: spring-cloud.enabled (cascades to sub-modules)
    └── auth-toms.md                  # Conditional: auth.toms.enabled
```

The index file `docs/java-coding-standards.md` retains its path so the existing "Step 0" wording in skills still resolves. It contains no rule content — only:

- A short header explaining the loading model
- An applicability table (file → gate)
- Links to each rule file and to `project-info.schema.yaml`
- A pointer to `jkit standards list` for selective loading

Every rule file opens with a one-line applicability header: conditional files use **Applies when:** naming the exact `project-info.yaml` key driving the gate; always-applies files use **Applies always.** This makes file purpose self-evident without depending on the index.

## `project-info.yaml` Schema

Authored per project, gates conditional rules and supplies environment-specific values. Shipped template at `docs/project-info.schema.yaml`:

```yaml
# jkit project info — copy to docs/project-info.yaml and customize.
# Fields with `enabled` flags gate which standards files apply.
# Run `jkit standards list --explain` to see active gates.

project:
  name: my-app                        # maven artifactId, log file name
  package: com.newland.myapp          # default: com.newland.{name}
  server-port: 3000                   # default: random 3000-3999

stack:
  java: 17
  spring-boot: 3.3.13
  mybatis-plus: 3.5.6

# gates standards/database.md
database:
  enabled: true
  type: mysql                         # only mysql supported
  name: my_app_db

# gates standards/tenant.md
# independent of auth.toms.enabled
tenant:
  enabled: true

# gates standards/i18n.md
i18n:
  enabled: true
  languages: [zh, en, pt, ja]

# gates standards/redis.md
redis:
  enabled: true

# gates standards/spring-cloud.md and all sub-modules
spring-cloud:
  enabled: false
  discovery:
    component: nacos                  # nacos | eureka | consul | zookeeper
  config-center:
    enabled: true
    component: nacos
  circuit-breaker:
    enabled: true
    component: sentinel               # sentinel | resilience4j
  gateway:
    enabled: false

# gates standards/auth-toms.md
auth:
  toms:
    enabled: true
    api-version: 3.4.00-JDK17-SNAPSHOT

# referenced by standards/java-coding.md (Maven Repositories section)
maven:
  repositories:
    - id: aliyun-repos
      url: https://maven.aliyun.com/repository/public
      snapshots: false
    - id: maven-snapshots
      url: http://192.168.132.145:54002/nexus/repository/maven-snapshots/
```

**Conventions:**

- Top-level keys map 1:1 to rule files (`i18n` ↔ `i18n.md`, etc.) for predictability.
- `spring-cloud.enabled: false` short-circuits all sub-modules regardless of their own `enabled` flags.
- `tenant.enabled` and `auth.toms.enabled` are independent. A service can be multi-tenant data-wise without using TOMS auth (e.g., behind a gateway injecting tenant headers).
- Environment-specific addresses (nacos, eureka server URLs etc.) stay in `.env.{env}.{component}` files per `environment.md`. `project-info.yaml` selects components, not addresses.

## Loading Flow

A new CLI subcommand selects applicable rule files. The example outputs below assume a `project-info.yaml` where `i18n.enabled=false` and `spring-cloud.enabled=false` (different from the shipped template, to illustrate skipping):

```
$ jkit standards list
<plugin-root>/docs/standards/java-coding.md
<plugin-root>/docs/standards/api.md
<plugin-root>/docs/standards/exception.md
<plugin-root>/docs/standards/environment.md
<plugin-root>/docs/standards/database.md
<plugin-root>/docs/standards/tenant.md
<plugin-root>/docs/standards/redis.md
<plugin-root>/docs/standards/auth-toms.md
```

```
$ jkit standards list --explain
java-coding.md   applies (always)
api.md           applies (always)
exception.md     applies (always)
environment.md   applies (always)
database.md      applies (database.enabled=true)
tenant.md        applies (tenant.enabled=true)
i18n.md          skipped (i18n.enabled=false)
redis.md         applies (redis.enabled=true)
spring-cloud.md  skipped (spring-cloud.enabled=false)
auth-toms.md     applies (auth.toms.enabled=true)
```

Behavior:

- Reads `docs/project-info.yaml` from the current project.
- If the file is missing, prints a clear error pointing to `jkit standards init` (creates the file by copying the template) and exits non-zero. Never silently default — a missing config is a setup bug.
- Output paths are absolute and resolved against the plugin root (so the harness can run `Read` on each).

Skill "Step 0" wording changes from:

> Read `<plugin-root>/docs/java-coding-standards.md`. Apply all rules.

To:

> Run `jkit standards list` and read every file it prints. Apply all rules.

Skills affected (citation update is mechanical):

- `skills/java-tdd/SKILL.md`
- `skills/java-verify/SKILL.md`
- `skills/scenario-tdd/SKILL.md`
- `docs/superpowers/specs/2026-04-21-jkit-iter1-foundation.md`
- `docs/superpowers/specs/2026-04-21-jkit-iter2-core-loop.md`
- `docs/superpowers/specs/2026-04-21-jkit-iter3-quality-layer.md`
- `docs/superpowers/plans/2026-04-22-jkit-iter2-core-loop.md`
- `docs/superpowers/plans/2026-04-22-jkit-iter3-quality-layer.md`

## Content per File

For each new file: the source material, what survives, what's reconciled, and what improvements apply. (Improvements: **A** = fix internal bugs, **B** = strengthen Checks, **C** = normalize applicability headers, **D** = extract environment-specific values to `project-info.yaml`, **E** = dedupe overlap.)

### `docs/java-coding-standards.md` (index)

New, short. Sections:

- Header: how the index works, what the loading model is.
- Applicability table — file × gate × purpose.
- Links to each rule file and to `project-info.schema.yaml`.
- Pointer to `jkit standards list` and `--explain`.

### `docs/standards/java-coding.md` (always)

Source: `java-coding-rule.md`.

- **Survives:** technology stack section (with values now sourced from `project-info.yaml > stack`), package/port section, layered architecture, method constraints, comment standards (incl. layer-specific Javadoc table and key-step comment requirements), large data handling (pagination + import/export), Spring profile conventions, externalizing configurable values, logging configuration (Logger declaration, content rules, Logback config, levels per env), DAO `@TableField` rule, Maven commands.
- **Folded in from current generic doc:** "one public class per file" (not in source); test method naming pattern `methodName_scenarioDescription` (move under "Testing" subsection).
- **D extracted:** Maven Repositories block becomes "Repositories MUST come from `project-info.yaml > maven.repositories`. Apply each entry verbatim under `<repositories>` in `pom.xml`, placed after `</dependencies>` and before `<build>`." No URLs in this file.
- **B added:** Checks for the Logging section — `@Slf4j` annotation present? `logback-spring.xml` exists (not `logback.xml`)? Log path uses `${LOG_PATH}` env var? Rolling policy configured (daily, gz compress, 30-day, 10 GB)? No `System.out`/`System.err` calls anywhere?
- **B added:** Checks for Externalizing Configurable Values — no `@Scheduled(cron = "0 0 …")` literal in source? No hardcoded timeouts/retry counts/batch sizes/feature toggles in Java?

### `docs/standards/api.md` (always)

Source: `api-rule.md`. Largely as-is.

- **E:** "no try/catch in Controllers" and "global `@RestControllerAdvice`" stay here as canonical statements; corresponding lines in `exception.md` become one-line cross-references.

### `docs/standards/exception.md` (always)

Source: `exception-rule.md`.

- **Survives:** four-type taxonomy (`AppBizException`, `AppRtException`, `PermissionException`, `SQLException`), single `ErrorCode` class/enum, separate `@ExceptionHandler` for `SQLException` with full stack-trace logging.
- **E:** Trim controller try/catch and `@RestControllerAdvice` rules to cross-references — canonical home is `api.md`.
- **B added:** Checks that `AppRtException` and `PermissionException` are mapped in the global handler (currently only `AppBizException` and `SQLException` have explicit checks).

### `docs/standards/environment.md` (always) — new

Source: `rules/environment-rule.md`.

- **Survives:** "MUST NOT hardcode host/port/username/password"; env file detection priority `.env.dev.*` → `.env.test.*` → `.env.inte.*`; "ask the user when none found, never assume defaults".
- **C:** Reformatted with the same applicability header style (here: "Applies always.").
- **B added:** Checks: no plain-text passwords/hosts in any `application*.yml` or Java source; `.env.*` files are gitignored.
- **Cross-referenced from:** `spring-cloud.md` (env file convention), `database.md` (DB credentials), `redis.md` (Redis address).

### `docs/standards/database.md` (conditional: `database.enabled`) — new

Sources: `mysql-rule.md` (primary), DAO Model Rules from `java-coding-rule.md` (folded in here, since they're DB-specific).

- **Applies when:** `database.enabled: true` and `database.type: mysql`. Default `database.enabled: true`.
- **Survives:** `mysql-schema.sql` structure (CREATE DATABASE, USE, qualified table names), ORM rules (MyBatis-Plus only, `BaseMapper<T>`, forbidden `@Select`/`@Insert`/`@Update`/`@Delete` on DAO, all SQL in XML mapper files, namespace matches DAO package), table prefix `t_*`, no foreign keys, VARCHAR length matrix vs TEXT, PK naming (`{entity}_id` for INT/BIGINT, `{entity}_uuid` for VARCHAR), mandatory audit columns (`cre_time`, `cre_user_id`, `upd_time`, `upd_user_id`), default `NOT NULL`, no `SELECT *`, queries use indexed columns.
- **Folded in:** DAO Model Rules' `@TableField` rule for MySQL reserved words (was in `java-coding-rule.md`).
- **A:** Drop the orphan instruction in `mysql-rule.md`: "Before proceeding, read all files under `../generate/reference/`" — irrelevant inside jkit.
- **B added:** Checks: every DAO extends `BaseMapper`? No `@Select`/`@Insert`/`@Update`/`@Delete` on any DAO method? Every XML mapper has matching DAO package namespace? Every table is `t_*` and prefixed with database name in DDL? Every table has full audit-column set? No `FOREIGN KEY` in DDL? No `SELECT *` in any XML mapper or `LambdaQueryWrapper`?
- The "ask the user when length is ambiguous" guidance for VARCHAR remains, reframed as instruction to the model: ask before generating ambiguous types.

### `docs/standards/tenant.md` (conditional: `tenant.enabled`) — new

Source: `tenant-rule.md`. Translate from Chinese to English; preserve identifier values (`ADMIN`/`OPERATOR`/`MERCHANT`/`DEV`) verbatim.

- **Applies when:** `tenant.enabled: true`. Independent of `auth.toms.enabled`.
- **Survives:** identity columns (`character_code` VARCHAR(32) NOT NULL, `key_id` BIGINT NOT NULL, both required together), which tables need them (business primary tables + denormalized child tables), which don't (system dictionaries, pure M:N tables, system logs), column definitions, indexes (composite `(character_code, key_id, status)`, unique `(character_code, key_id, {field})`, child-table FK column index), query patterns (main table = explicit `WHERE character_code AND key_id`, child via FK; uniqueness checks must include tenant), denormalized children copy from main table not from `UserContext`.
- **Cross-referenced into:** `redis.md` (tenant-scoped key format), `auth-toms.md` (`CharacterEnum` mapping). Canonical home for the identity scheme is here.
- **B added:** Checks: every business main table has both columns? Every such table has a composite tenant index? Every uniqueness query includes tenant filter? No child-table assignment of `character_code`/`key_id` from `UserContext`?

### `docs/standards/i18n.md` (conditional: `i18n.enabled`)

Source: `i18n-rule.md`.

- **Applies when:** `i18n.enabled: true`. Languages from `i18n.languages`.
- **C:** Add applicability header.
- **B added:** Checks: every key present in *all* configured language files? No hardcoded user-facing strings in Controller/Service responses?

### `docs/standards/redis.md` (conditional: `redis.enabled`)

Source: `redis-rule.md`. Largely as-is.

- **C:** Add applicability header.
- Tenant-scoped key format `{charactorCode}:{keyId}:{entity}` references `tenant.md` for the identity scheme.

### `docs/standards/spring-cloud.md` (conditional: `spring-cloud.enabled`)

Source: `spring-cloud-rule.md`.

- **Applies when:** `spring-cloud.enabled: true`. Each sub-module additionally checks its own `enabled` (cascade: top-level false skips everything).
- **C:** Replace bespoke "Pre-Flight Check" with the standard applicability header.
- **E:** Trim env-file detection prose; cross-reference `environment.md` for the priority rule. This file keeps only the per-component variable list.
- **D extracted:** Default addresses table (`127.0.0.1:8848` for nacos, etc.) moves to `project-info.yaml > spring-cloud.{module}.default-address`. Standards file says "use the address from the env file; if absent, fall back to `project-info.yaml > spring-cloud.{module}.default-address`."
- Component selection comes from `project-info.yaml` (e.g., `spring-cloud.discovery.component: nacos`); no longer from per-project `project-info.md` prose.

### `docs/standards/auth-toms.md` (conditional: `auth.toms.enabled`)

Source: `toms-authorization-rule.md`.

- **Applies when:** `auth.toms.enabled: true`.
- **A fixed:** §2 currently says "Register `PlatformWebAuthInterceptor`" but the code block registers `UserContextInterceptor`. Rewrite §2 to actually register `PlatformWebAuthInterceptor` (with the documented `@Permission` validation behavior). §3 keeps `UserContextInterceptor` with its correct registration. §3's "Register **after** `PlatformWebAuthInterceptor`" line moves into §3 only — §2 stays focused on the auth interceptor.
- **A fixed:** §3 code uses `StringRedisTemplate` in the field but `RedisTemplate<String, Object>` in §2's example. Standardize on `StringRedisTemplate` throughout.
- **D extracted:** `authorization-api-version` default (`3.4.00-JDK17-SNAPSHOT`) moves to `project-info.yaml > auth.toms.api-version`. Standards file reads "use the version from `project-info.yaml > auth.toms.api-version`" with no embedded default.
- **Survives:** `UserContext` ThreadLocal store + prohibition of mock/fallback branch, `@Permission` annotation generation flow (driven by the project's permission table), all six annotation patterns (5.1–5.6), `PowerConst` derivation rule and class structure, prohibitions for production and test code.
- The example permission codes (`124012.MANAGE`, etc.) remain inline as illustrations, with a header note: "Example values only. Real codes come from `docs/domains/*/api-implement-logic.md` per project."

## Implementation Outline

The plan that follows from this spec will sequence the work roughly as:

1. Add `jkit standards list` (and `init`, `--explain`) subcommand to the Rust CLI; ship `project-info.schema.yaml`.
2. Author the 10 rule files under `docs/standards/` and the new index.
3. Update Step 0 wording in the three skills and the spec/plan docs.
4. Delete the old generic content from `docs/java-coding-standards.md` (or rather, replace with the index).
5. Add a smoke test: with a fixture `project-info.yaml`, `jkit standards list` returns the expected files; `--explain` matches expected gate decisions.

Detailed sequencing belongs in the implementation plan (writing-plans skill).

## Risks and Trade-offs

- **Coupling jkit to the Newland stack.** Per option C in brainstorming, this is intentional. If jkit later wants to support non-Newland stacks, profiles or a stack-selector field in `project-info.yaml` could be introduced — out of scope here.
- **`project-info.yaml` becomes a required artifact for every jkit project.** `migrate-project` must ensure it exists; missing-file errors from `jkit standards list` must be actionable.
- **Translation of `tenant-rule.md` from Chinese to English** introduces some authoring judgment. Will preserve identifier values verbatim and cross-check semantic intent against the original.
- **Cross-references between files** (api↔exception, redis↔tenant, environment↔spring-cloud) need to stay consistent. Mitigation: each cross-reference is one line and uses a concrete anchor; spec self-review can sanity-check linkage during implementation.

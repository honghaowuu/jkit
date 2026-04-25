# Java Coding Standards

These rules apply to all Java code generated or modified by jkit skills. Skills load this index at "Step 0" and use `jkit standards list` to fetch the per-project applicable files.

## Loading

Run `jkit standards list` from the project root to print the absolute paths of files that apply to the current project. The result depends on `docs/project-info.yaml` (see [`project-info.schema.yaml`](project-info.schema.yaml) for the canonical template). Use `jkit standards list --explain` to see why each file applies or is skipped.

If `docs/project-info.yaml` is missing, run `jkit standards init` to create it from the shipped template, then customize.

## Applicability

| File | Applies when | Purpose |
|------|--------------|---------|
| [`standards/java-coding.md`](standards/java-coding.md) | always | Naming, layering, comments, large data, logging, Maven |
| [`standards/api.md`](standards/api.md) | always | REST verbs, paths, validation, error format |
| [`standards/exception.md`](standards/exception.md) | always | Exception taxonomy + `ErrorCode` + handler |
| [`standards/environment.md`](standards/environment.md) | always | No hardcoded host/port/credentials; `.env.{env}.*` priority |
| [`standards/database.md`](standards/database.md) | `database.enabled: true` | MySQL DDL, MyBatis-Plus, audit columns, query rules |
| [`standards/tenant.md`](standards/tenant.md) | `tenant.enabled: true` | `character_code`/`key_id` multi-tenancy, indexes, query patterns |
| [`standards/i18n.md`](standards/i18n.md) | `i18n.enabled: true` | i18n key conventions across language files |
| [`standards/redis.md`](standards/redis.md) | `redis.enabled: true` | Tenant-scoped key naming, mandatory TTL |
| [`standards/spring-cloud.md`](standards/spring-cloud.md) | `spring-cloud.enabled: true` | Discovery, config center, circuit breaker, gateway |
| [`standards/auth-toms.md`](standards/auth-toms.md) | `auth.toms.enabled: true` | `@Permission`, `UserContext`, `PowerConst` |

## See also

- [`project-info.schema.yaml`](project-info.schema.yaml) — canonical schema and defaults for `docs/project-info.yaml`

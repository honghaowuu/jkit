<jkit-project-context>
This is a jkit-managed Java/Spring Boot microservice project. Apply these conventions throughout the session.

## Commit conventions

| Prefix | When to use |
|--------|-------------|
| `docs(spec):` or `docs(<domain>):` | Spec change in docs/domains/ |
| `feat(impl):` | New feature implementation |
| `fix(impl):` | Bug fix implementation |
| `chore(impl):` | Non-feature implementation work |

Edit `docs/domains/` only via `/spec-delta`, never directly.

If state looks inconsistent, run `jkit changes doctor` for a read-only diagnostic.

## Environment

Single `application.yml` with `${ENV_VAR:default}`. No `application-{profile}.yml` profiles.

`direnv` auto-loads env vars on `cd`. Two supported layouts (choose one per project):
- Single file: `.env/local.env`, `.env/test.env`
- Directory (split by concern): `.env/local/db.env`, `.env/local/kafka.env`, …

Switch envs: `JKIT_ENV=test direnv exec . <cmd>`

## Skills — when to invoke

- `/migrate-project` — bootstrap a fresh project for the spec-delta workflow
- `/write-change` — author a new change file in `docs/changes/pending/`
- `/spec-delta` — implement pending change files: update formal docs, plan, code
- `/sql-migration` — author Liquibase/Flyway migrations for schema-changing deltas
- `/plan-upstream-deps` — pre-flight scan for cross-service deps before `/java-tdd` (SDK / Feign / mock plan)
- `/java-tdd` — implement a plan via TDD with JaCoCo coverage analysis
- `/scenario-tdd` — implement integration test gaps from change-summary.md
- `/java-verify` — quality gates: mvn verify + merged coverage + API coverage
- `/publish-contract` — generate and push the 4-level service contract
- `/generate-feign` — generate a Feign client from an installed contract plugin
- `bin/install-contracts.sh` — add upstream service contract plugins as dependencies
</jkit-project-context>

<jkit-project-context>
This is a jkit-managed Java/Spring Boot microservice project. Apply these conventions throughout the session.

## Commit conventions

| Prefix | When to use |
|--------|-------------|
| `docs(spec):` or `docs(<domain>):` | Spec change in docs/domains/ |
| `feat(impl):` | New feature implementation |
| `fix(impl):` | Bug fix implementation |
| `chore(impl):` | Non-feature implementation work |

After `java-tdd` finishes the final task of a plan, it calls `jkit changes complete --run <run>` which moves the processed change files from `docs/changes/pending/` to `docs/changes/done/`, archives the run dir to `.jkit/done/`, and amends the impl commit. There is no implicit post-commit hook — completion is explicit.

Edit `docs/domains/` only via `/spec-delta`, never directly. Direct edits will be overwritten on the next cycle.

## Environment

Single `application.yml` with `${ENV_VAR:default}`. No `application-{profile}.yml` profiles.

`direnv` auto-loads env vars on `cd`. Two supported layouts (choose one per project):
- Single file: `.env/local.env`, `.env/test.env`
- Directory (split by concern): `.env/local/db.env`, `.env/local/kafka.env`, …

Switch envs: `JKIT_ENV=test direnv exec . <cmd>`

## Skills — when to invoke

- `/migrate-project` — bootstrap a fresh project: create `docs/changes/{pending,done}/` and explain how to write the first change file
- `/spec-delta` — start here: pick up pending change files in docs/changes/pending/, update formal docs, then drive the full cycle to commit
- `/sql-migration` — author Liquibase or Flyway migrations aligned with a schema-changing spec delta
- `/java-tdd` — implement a plan via TDD with JaCoCo unit coverage gap analysis
- `/scenario-tdd` — implement integration test gaps from change-summary.md, one scenario at a time
- `/java-verify` — run quality gates: mvn verify + merged coverage + API coverage + code review handoff
- `/publish-contract` — generate and push the 4-level service contract for other teams
- `bin/install-contracts.sh` — add upstream service contract plugins as dependencies
- `/generate-feign` — generate a Feign client from an installed contract plugin
</jkit-project-context>

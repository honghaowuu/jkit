<jkit-project-context>
This is a jkit-managed Java/Spring Boot microservice project. Apply these conventions throughout the session.

## Commit conventions

| Prefix | When to use |
|--------|-------------|
| `docs(spec):` or `docs(<domain>):` | Spec change in docs/domains/ |
| `feat(impl):` | New feature implementation |
| `fix(impl):` | Bug fix implementation |
| `chore(impl):` | Non-feature implementation work |

The `(impl):` scope triggers the post-commit hook to update `.jkit/spec-sync`. Always use a scoped commit for implementation work.

## Environment

Single `application.yml` with `${ENV_VAR:default}`. No `application-{profile}.yml` profiles.

`direnv` auto-loads env vars on `cd`. Two supported layouts (choose one per project):
- Single file: `.env/local.env`, `.env/test.env`
- Directory (split by concern): `.env/local/db.env`, `.env/local/kafka.env`, …

Switch envs: `JKIT_ENV=test direnv exec . <cmd>`

## Skills — when to invoke

- `/spec-delta` — start here: compute what changed in docs/domains/ since last implementation, then drive the full cycle to commit
- `/java-tdd` — implement a plan via TDD with JaCoCo unit coverage gap analysis
- `/scenario-tdd` — implement integration test gaps from change-summary.md, one scenario at a time
- `/java-verify` — run quality gates: mvn verify + merged coverage + API coverage + code review handoff
- `/publish-contract` — generate and push the 4-level service contract for other teams
- `/install-contracts` — add upstream service contract plugins as dependencies
- `/generate-feign` — generate a Feign client from an installed contract plugin
</jkit-project-context>

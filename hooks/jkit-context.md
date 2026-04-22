This is a jkit-managed Java/Spring Boot microservice project.

## Commit conventions

| Prefix | When to use |
|--------|-------------|
| `docs(spec):` or `docs(<domain>):` | Spec change in docs/domains/ |
| `feat(impl):` | New feature implementation |
| `fix(impl):` | Bug fix implementation |
| `chore(impl):` | Non-feature implementation work |

The `(impl):` scope triggers the post-commit hook to update `.jkit/spec-sync`.

## Environment

Single `application.yml` using `${ENV_VAR:default}`. No `application-{profile}.yml` files.
- Local dev: `direnv` auto-loads `.env/local.env` when you enter the project directory
- Other envs: `JKIT_ENV=test direnv exec . <cmd>`

## Key skills

- **spec-delta** — compute requirements delta since last implementation → drives full spec-to-commit cycle
- **java-tdd** — TDD implementation with JaCoCo unit coverage gap analysis
- **scenario-gap** — detect unimplemented scenarios per domain from test-scenarios.md; invoked by spec-delta
- **scenario-tdd** — implement missing scenarios via integration TDD: one at a time, RED → GREEN
- **java-verify** — quality gate: mvn verify + merged coverage check + code review handoff
- **publish-contract** — generate 4-level progressive disclosure contract for other services to consume

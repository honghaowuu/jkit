# Project Conventions

## Commit Prefixes

| Prefix | Meaning |
|--------|---------|
| `docs(spec):` or `docs(<domain>):` | Spec change |
| `feat(impl):` | New feature implementation |
| `fix(impl):` | Bug fix implementation |
| `chore(impl):` | Non-feature implementation work |
| `chore(migrate):` | Project migration commit |

The `(impl):` scope triggers the post-commit hook to update `docs/.spec-sync`.

## Environment Variables

- Single `application.yml` using `${ENV_VAR:default}` substitution
- No `application-{profile}.yml` files
- Load env: `source .env/<env>.env && mvn <command>`
- Test: `source .env/test.env && mvn test`

## Running Integration Tests

```bash
source .env/test.env && mvn test -Dtest=*IntegrationTest
```

## Workflow

1. Edit `docs/` spec files
2. Commit with `docs(spec):` or `docs(<domain>):`
3. Run `/spec-delta` to compute delta and generate plan
4. Implement using `/java-tdd` per task
5. Test APIs using `/contract-testing` per domain
6. Commit with `feat(impl):` — post-commit hook updates `.spec-sync`
7. Run `/publish-contract` to update service contract

## jkit Artifacts

Each implementation run creates `docs/jkit/YYYY-MM-DD-<feature>/`:
- `change-summary.md` — review before planning
- `contract-tests.md` — review before test generation
- `migration-preview.md` — review before SQL generation
- `migration/` — generated SQL (moved to `src/main/resources/db/migration/` in final commit)
- `plan.md` — implementation plan

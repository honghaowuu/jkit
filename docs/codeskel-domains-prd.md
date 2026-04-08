# codeskel domains — PRD

**Problem:** Migrating existing Java microservices to the standard doc structure
requires identifying subdomain boundaries. Reading all Java files with Claude is
token-expensive and imprecise. A deterministic scanner eliminates this cost.

**Approach:** Add a `domains` subcommand to the existing `codeskel` CLI. All
required data (packages, class-level annotations) is already collected by
`codeskel scan` via tree-sitter. No new tool or new parsing logic needed.

## Detection Rules

| Signal | Role |
|--------|------|
| Package name segments (`com.example.billing`) | Primary grouping key |
| `@RestController` base path prefix (`/billing/**`) | Primary confirmation |
| `@Entity` / `@Aggregate` package grouping | Secondary |
| `@Service` package grouping | Secondary |

## CLI Interface

```
codeskel domains <project_root> [OPTIONS]

Options:
  --output <path>       Write JSON to file (default: stdout)
  --pretty              Pretty-print output
  --min-classes <n>     Minimum classes to qualify as a subdomain [default: 2]
  --src <path>          Override source root [default: src/main/java]
```

## Output Format

```json
{
  "detected_subdomains": [
    {
      "name": "billing",
      "package": "com.example.billing",
      "controllers": ["InvoiceController", "PaymentController"],
      "entities": ["Invoice", "Payment"],
      "services": ["InvoiceService"]
    }
  ],
  "ambiguous": ["SharedUtils", "AuditLog"],
  "stats": { "total_classes": 47, "unmapped": 3 }
}
```

## Exit Codes

Follows existing `codeskel` conventions:
- `0` = success
- `1` = fatal error
- `2` = partial success with warnings

## Non-Goals

- Does not read method bodies
- Does not infer business logic or domain relationships
- Does not generate docs (Claude's responsibility)

## Implementation Notes

- Reuse `.codeskel/cache.json` if present; run `codeskel scan` first if not
- Group by top-level package segment after the group ID prefix
  (e.g., `com.newland` prefix → `billing` from `com.newland.billing`)
- Annotation detection reuses existing tree-sitter parsing — no raw regex
- Rust, same codebase as `codeskel`

# jkit CLI Reference

> Author aid — not shipped with the plugin. Documents the pre-built `bin/jkit` binary.

## Subcommands

| Subcommand | Purpose |
|------------|---------|
| `jkit skel <path>` | Scan Java source under `<path>`, output JSON array of class/method signatures |
| `jkit skel domains <root>` | Scan all domain packages under `<root>` |
| `jkit coverage <jacoco.xml>` | Analyze JaCoCo XML report, output coverage gaps |
| `jkit coverage --api <domains-dir> <test-src-dir>` | Compare declared API endpoints vs RestAssured-tested endpoints |
| `jkit scan spring` | Scan Spring Boot project structure |
| `jkit scan contract` | Scan for contract artifacts |
| `jkit scan schema` | Scan for schema migration files |
| `jkit scan project` | Full project scan |

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Fatal error |
| 2 | Partial success with warnings |

---

## `jkit skel <path>`

Scans Java source under `<path>`, outputs JSON array of class/method signatures. Used by `publish-contract` for Javadoc quality checks and by `scenario-gap` for test method discovery.

**Output format:**

```json
[
  {
    "class": "com.example.InvoiceController",
    "annotation": "@RestController",
    "methods": [
      {
        "name": "createInvoice",
        "signature": "ResponseEntity<InvoiceResponse> createInvoice(InvoiceRequest request)",
        "has_docstring": true,
        "docstring_text": "Creates a new invoice for the given tenant."
      },
      {
        "name": "getInvoice",
        "signature": "ResponseEntity<InvoiceResponse> getInvoice(UUID id)",
        "has_docstring": false
      }
    ]
  }
]
```

**Notes:**
- `has_docstring`: true if the method has a Javadoc comment
- `docstring_text`: only present when `has_docstring` is true
- A method with `has_docstring: false` or empty `docstring_text` fails the Javadoc quality check in `publish-contract`

---

## `jkit coverage <jacoco.xml>`

Analyzes a JaCoCo XML report for coverage gaps.

**Flags:**
- `--summary` — output a one-line summary instead of full method list
- `--min-score <float>` — filter to methods below this coverage score (0.0–1.0)

**Output format:**

```json
{
  "total_methods": 42,
  "covered_methods": 38,
  "gaps": [
    {
      "class": "com.example.InvoiceService",
      "method": "validateBulkInvoice",
      "branch_coverage": 0.5,
      "line_coverage": 0.6
    }
  ]
}
```

---

## `jkit coverage --api <domains-dir> <test-src-dir>`

Reads all `api-spec.yaml` files under `<domains-dir>`, scans `<test-src-dir>` for RestAssured URL patterns, outputs endpoint coverage gaps.

**Output format:**

```json
{
  "endpoints_declared": 12,
  "endpoints_tested": 10,
  "gaps": [
    {
      "method": "POST",
      "path": "/invoices/bulk",
      "declared_in": "docs/domains/billing/api-spec.yaml"
    }
  ]
}
```

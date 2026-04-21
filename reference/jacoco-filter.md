# jacoco-filter

A fast, cross-platform CLI tool that parses JaCoCo XML coverage reports, filters out trivial and fully-covered methods, and scores the remaining methods by complexity × coverage gap. The compact JSON output is designed to be fed into Claude Code to guide targeted test generation.

## Features

- Filters constructors, getters, and setters automatically
- Skips fully-covered methods (no missed lines)
- Scores each method: `complexity × (missed_lines / total_lines)`
- Reports overall and per-class line coverage percentage (`--summary`)
- Outputs compact or pretty-printed JSON
- Supports a minimum score threshold to focus on high-priority gaps
- Single static binary — no runtime dependencies

## Quick Start

### 1. Build

```bash
git clone <repo-url>
cd jacoco-filter
cargo build --release
```

The binary will be at `target/release/jacoco-filter`.

### 2. Generate a JaCoCo report

```bash
mvn clean test jacoco:report
# Report is written to target/site/jacoco/jacoco.xml
```

### 3. Run the filter

```bash
# Print to stdout (compact JSON — methods array)
jacoco-filter target/site/jacoco/jacoco.xml

# Include overall line coverage summary
jacoco-filter target/site/jacoco/jacoco.xml --summary --pretty

# Only show methods with a score above 1.5
jacoco-filter target/site/jacoco/jacoco.xml --min-score 1.5 --pretty

# Pretty-print and save to a file
jacoco-filter target/site/jacoco/jacoco.xml --summary --pretty --output coverage-gaps.json
```

### 4. Install the Claude Code skill (optional)

If you use Claude Code in your Java project, copy the bundled skill so Claude knows how to run jacoco-filter automatically:

```bash
mkdir -p /path/to/your-java-project/.claude/skills
cp -r skill/jacoco-filter /path/to/your-java-project/.claude/skills/
```

Once installed, Claude Code will automatically use `jacoco-filter` whenever you ask it to analyze coverage — and will never attempt to read `jacoco.xml` directly.

### 5. Feed output to Claude Code

```bash
claude "Here are the highest-priority coverage gaps. Please write tests for these methods." \
  --file coverage-gaps.json
```

## Output Format

### Default — methods array

Results are sorted by score descending:

```json
[
  {
    "class": "com.example.billing.InvoiceService",
    "source_file": "InvoiceService.java",
    "method": "calculateDiscount",
    "score": 4.5,
    "missed_lines": [42, 43, 47, 51]
  }
]
```

| Field | Description |
|---|---|
| `class` | Fully-qualified class name (dots) |
| `source_file` | Java source file name |
| `method` | Method name |
| `score` | `complexity × (missed / total)` — higher means more urgent |
| `missed_lines` | Line numbers with no coverage (`mi > 0` or `mb > 0`) |

### With `--summary`

Wraps the methods array in an object with a coverage summary:

```json
{
  "summary": {
    "line_coverage_pct": 72.4,
    "lines_covered": 842,
    "lines_missed": 321,
    "by_class": [
      {
        "class": "com.example.billing.InvoiceService",
        "source_file": "InvoiceService.java",
        "line_coverage_pct": 45.0,
        "lines_covered": 9,
        "lines_missed": 11
      }
    ]
  },
  "methods": [ ... ]
}
```

`by_class` is sorted ascending by `line_coverage_pct` (worst-covered first). Use `jq` to pull out just the number you need:

```bash
# Overall coverage percentage
jacoco-filter jacoco.xml --summary | jq '.summary.line_coverage_pct'

# Pass/fail against an 80% target
jacoco-filter jacoco.xml --summary | jq 'if .summary.line_coverage_pct >= 80 then "PASS" else "FAIL" end'

# Five worst-covered classes
jacoco-filter jacoco.xml --summary | jq '.summary.by_class[:5] | [.[] | {class, line_coverage_pct}]'
```

## CLI Reference

```
jacoco-filter <input_file> [OPTIONS]

Arguments:
  <input_file>   Path to jacoco.xml

Options:
  --output <path>       Write JSON to file (default: stdout)
  --min-score <float>   Exclude methods below this score (default: 0.0)
  --pretty              Pretty-print JSON output
  --summary             Include line-coverage summary in output
  -h, --help            Print help
  -V, --version         Print version
```

## Filtering Rules

| Rule | Methods skipped |
|---|---|
| Constructors | Methods named `<init>` |
| Getters | Methods starting with `get` |
| Setters | Methods starting with `set` |
| Full coverage | Methods with zero missed lines |

## Scoring

```
score = complexity × (missed_line_count / total_line_count)
```

- **complexity** — sum of missed + covered from the `COMPLEXITY` counter
- **missed_line_count** — number of lines attributed to this method where `mi > 0` or `mb > 0`
- **total_line_count** — sum of missed + covered from the `LINE` counter

A score of `0.0` means either the method is fully covered or has no lines.

## Development

```bash
cargo build        # debug build
cargo test         # run all tests
cargo clippy       # lint
cargo fmt          # format
```

## License

MIT

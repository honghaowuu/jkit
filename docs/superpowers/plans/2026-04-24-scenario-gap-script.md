# scenario-gap Script Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the `scenario-gap` LLM skill with a deterministic Rust binary and update all skills to use the new YAML format and binary call.

**Architecture:** The Rust binary `scenario-gap` reads `docs/domains/<domain>/test-scenarios.yaml`, optionally filters to git-diff-new entries only, greps test files for method declarations, and outputs a compact JSON gap list. Skills are updated to call the binary directly and reference `.yaml` instead of `.md`.

**Tech Stack:** Rust, `serde`/`serde_yaml`/`serde_json`/`clap` crates, `grep` for method detection, `git diff` for `--new` filtering.

---

## File Map

| File | Change |
|---|---|
| `skills/spec-delta/SKILL.md` | Step 7b: `.md` → `.yaml`, format block; Step 9: replace sub-skill with binary call; directory comment: `.md` → `.yaml` |
| `skills/scenario-gap/SKILL.md` | Delete |
| `skills/publish-contract/SKILL.md` | Strip `bin/` prefix from 3 script calls |
| `skills/generate-feign/SKILL.md` | Strip `bin/` prefix from 2 `install-contracts.sh` references |
| `scenario-gap/` (new Rust crate) | New binary: `Cargo.toml`, `src/main.rs` |
| `bin/scenario-gap` | Compiled binary placed here (built by user) |

---

### Task 1: Update spec-delta — `.md` → `.yaml` and Step 9

**Files:**
- Modify: `skills/spec-delta/SKILL.md`

- [ ] **Step 1: Update Step 7b heading and merge target**

Find:
```
**Step 7b: Sync test-scenarios.md**
```
Replace with:
```
**Step 7b: Sync test-scenarios.yaml**
```

Find:
```
Then merge into `docs/domains/<domain>/test-scenarios.md`:
```
Replace with:
```
Then merge into `docs/domains/<domain>/test-scenarios.yaml`:
```

- [ ] **Step 2: Update Step 7b format block**

The Step 7b format example is currently a markdown fence (`~~~markdown`). Replace it with a YAML fence showing the flat-list format. Find:

```
Format matches the existing `test-scenarios.md` convention:

~~~markdown
## POST /invoices/bulk
- happy-path: valid list of 3 → 201 + invoice IDs        ← always
- validation-amount-missing: missing amount field → 400    ← required field "amount"
- auth-missing-token: missing token → 401                  ← response 401
- business-duplicate-idempotency-key: duplicate idempotency key → 409  ← response 409
~~~
```

Replace with:

```
Format is a flat YAML list — one entry per scenario, append new blocks at end of file:

~~~yaml
- endpoint: "POST /invoices/bulk"
  id: happy-path
  description: valid list of 3 → 201 + invoice IDs        # always

- endpoint: "POST /invoices/bulk"
  id: validation-amount-missing
  description: missing amount field → 400                  # required field "amount"

- endpoint: "POST /invoices/bulk"
  id: auth-missing-token
  description: missing token → 401                         # response 401

- endpoint: "POST /invoices/bulk"
  id: business-duplicate-idempotency-key
  description: duplicate idempotency key → 409             # response 409
~~~
```

- [ ] **Step 3: Update Step 7b merge rule**

The merge rule currently uses heading-based logic matching the old markdown format. Replace the numbered list:

```
1. If the file does not exist → create it with all derived scenarios
2. If it exists → read it, then for each changed endpoint:
   - Heading (`## METHOD /path`) absent → append heading + all derived scenarios
   - Heading present → append only scenario IDs not already present under that heading
3. Never delete or reorder existing rows — only append
```

With:

```
1. If the file does not exist → create it with all derived scenario entries
2. If it exists → read it, collect all existing `id` values, then append new entries for IDs not already present
3. Never delete or reorder existing entries — only append
```

- [ ] **Step 4: Update Step 7b sync confirmation line**

Find:
```
After syncing `test-scenarios.md` for all changed domains, include the updated files in the same human review prompt from Step 7:
```
Replace with:
```
After syncing `test-scenarios.yaml` for all changed domains, include the updated files in the same human review prompt from Step 7:
```

- [ ] **Step 5: Replace Step 9**

Find and replace the entire Step 9 block:

```
**Step 9: Scenario gap detection**

For each changed domain that has `docs/domains/<domain>/test-scenarios.md`:

**REQUIRED SUB-SKILL: invoke `scenario-gap`**, passing the domain name. Collect all gaps across domains — written into change-summary.md in Step 11.
```

Replace with:

```
**Step 9: Scenario gap detection**

For each changed domain that has `docs/domains/<domain>/test-scenarios.yaml`:

```bash
scenario-gap <domain> --new
```

Read the JSON output (array of `{endpoint, id, description}` objects). Collect all gaps across domains — written into change-summary.md in Step 11. If output is `[]` for all domains, omit the Test Scenario Gaps section entirely.
```

- [ ] **Step 6: Update directory structure comment**

Find:
```
      test-scenarios.md             ← scenario gap source (AI-maintained)
```
Replace with:
```
      test-scenarios.yaml           ← scenario gap source (AI-maintained)
```

- [ ] **Step 7: Commit**

```bash
git add skills/spec-delta/SKILL.md
git commit -m "feat: migrate spec-delta to test-scenarios.yaml and scenario-gap binary"
```

---

### Task 2: Delete scenario-gap skill

**Files:**
- Delete: `skills/scenario-gap/SKILL.md`

- [ ] **Step 1: Delete the skill file**

```bash
rm skills/scenario-gap/SKILL.md
rmdir skills/scenario-gap
```

- [ ] **Step 2: Commit**

```bash
git add -A skills/scenario-gap/
git commit -m "feat: remove scenario-gap skill (replaced by binary)"
```

---

### Task 3: Fix bin/ prefix in publish-contract and generate-feign

**Files:**
- Modify: `skills/publish-contract/SKILL.md`
- Modify: `skills/generate-feign/SKILL.md`

- [ ] **Step 1: Fix publish-contract**

Find:
```bash
bin/contract-push.sh {service-name} {contractRepo}
bin/marketplace-publish.sh {marketplaceRepo} {service-name} "{description}" {contractRepo}
bin/marketplace-sync.sh {marketplaceRepo} {marketplaceName}
```
Replace with:
```bash
contract-push.sh {service-name} {contractRepo}
marketplace-publish.sh {marketplaceRepo} {service-name} "{description}" {contractRepo}
marketplace-sync.sh {marketplaceRepo} {marketplaceName}
```

- [ ] **Step 2: Fix generate-feign**

Find (line ~65):
```
> A) Run `bin/install-contracts.sh` now to add it (recommended)
```
Replace with:
```
> A) Run `install-contracts.sh` now to add it (recommended)
```

Find (line ~68):
```
On A: run `bin/install-contracts.sh` in the terminal, then continue from Step 3.
```
Replace with:
```
On A: run `install-contracts.sh` in the terminal, then continue from Step 3.
```

- [ ] **Step 3: Commit**

```bash
git add skills/publish-contract/SKILL.md skills/generate-feign/SKILL.md
git commit -m "fix: remove bin/ prefix from script calls (bin/ is in PATH)"
```

---

### Task 4: Build scenario-gap Rust binary

**Files:**
- Create: `scenario-gap/Cargo.toml`
- Create: `scenario-gap/src/main.rs`
- Output: `bin/scenario-gap` (after build)

- [ ] **Step 1: Create Cargo.toml**

```toml
[package]
name = "scenario-gap"
version = "0.1.0"
edition = "2021"

[[bin]]
name = "scenario-gap"
path = "src/main.rs"

[dependencies]
serde = { version = "1", features = ["derive"] }
serde_yaml = "0.9"
serde_json = "1"
clap = { version = "4", features = ["derive"] }
```

- [ ] **Step 2: Create src/main.rs**

```rust
use clap::Parser;
use serde::{Deserialize, Serialize};
use std::collections::HashSet;
use std::fs;
use std::process::{Command, exit};

#[derive(Parser)]
#[command(about = "Detect unimplemented test scenarios for a domain")]
struct Args {
    /// Domain name (e.g., billing)
    domain: String,

    /// Test source root
    #[arg(long, default_value = "src/test/java/")]
    test_root: String,

    /// Only check scenario IDs added in the current git diff
    #[arg(long)]
    new: bool,
}

#[derive(Debug, Deserialize)]
struct Scenario {
    endpoint: String,
    id: String,
    description: String,
}

#[derive(Debug, Serialize)]
struct Gap {
    endpoint: String,
    id: String,
    description: String,
}

fn kebab_to_camel(s: &str) -> String {
    let mut result = String::new();
    let mut capitalize_next = false;
    for ch in s.chars() {
        if ch == '-' {
            capitalize_next = true;
        } else if capitalize_next {
            result.push(ch.to_ascii_uppercase());
            capitalize_next = false;
        } else {
            result.push(ch);
        }
    }
    result
}

fn new_ids_from_git_diff(yaml_path: &str) -> HashSet<String> {
    let output = Command::new("git")
        .args(["diff", "HEAD", "--", yaml_path])
        .output()
        .unwrap_or_else(|e| { eprintln!("git diff failed: {e}"); exit(1); });

    let stdout = String::from_utf8_lossy(&output.stdout);
    let mut ids = HashSet::new();
    for line in stdout.lines() {
        // Added lines containing `  id: <value>`
        if let Some(rest) = line.strip_prefix("+  id: ") {
            ids.insert(rest.trim().to_string());
        }
    }
    ids
}

fn is_implemented(camel: &str, test_root: &str) -> bool {
    let pattern = format!(r"void {camel}\b");
    let output = Command::new("grep")
        .args(["-rn", "--include=*Test.java", &pattern, test_root])
        .output()
        .unwrap_or_else(|e| { eprintln!("grep failed: {e}"); exit(1); });
    !output.stdout.is_empty()
}

fn main() {
    let args = Args::parse();
    let yaml_path = format!("docs/domains/{}/test-scenarios.yaml", args.domain);

    let content = fs::read_to_string(&yaml_path).unwrap_or_else(|_| {
        // File not yet created — no gaps
        println!("[]");
        exit(0);
    });

    let scenarios: Vec<Scenario> = serde_yaml::from_str(&content).unwrap_or_else(|e| {
        eprintln!("YAML parse error in {yaml_path}: {e}");
        exit(1);
    });

    let filter: Option<HashSet<String>> = if args.new {
        let ids = new_ids_from_git_diff(&yaml_path);
        if ids.is_empty() {
            // Nothing new — no gaps
            println!("[]");
            exit(0);
        }
        Some(ids)
    } else {
        None
    };

    let gaps: Vec<Gap> = scenarios
        .into_iter()
        .filter(|s| filter.as_ref().map_or(true, |f| f.contains(&s.id)))
        .filter(|s| !is_implemented(&kebab_to_camel(&s.id), &args.test_root))
        .map(|s| Gap { endpoint: s.endpoint, id: s.id, description: s.description })
        .collect();

    println!("{}", serde_json::to_string(&gaps).unwrap());
}
```

- [ ] **Step 3: Write unit tests for kebab_to_camel**

Add a test module at the bottom of `src/main.rs`:

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_kebab_to_camel_single_word() {
        assert_eq!(kebab_to_camel("happy"), "happy");
    }

    #[test]
    fn test_kebab_to_camel_two_words() {
        assert_eq!(kebab_to_camel("happy-path"), "happyPath");
    }

    #[test]
    fn test_kebab_to_camel_three_words() {
        assert_eq!(kebab_to_camel("validation-empty-list"), "validationEmptyList");
    }

    #[test]
    fn test_kebab_to_camel_auth() {
        assert_eq!(kebab_to_camel("auth-missing-token"), "authMissingToken");
    }
}
```

- [ ] **Step 4: Run tests**

```bash
cd scenario-gap && cargo test
```

Expected output:
```
running 4 tests
test tests::test_kebab_to_camel_single_word ... ok
test tests::test_kebab_to_camel_two_words ... ok
test tests::test_kebab_to_camel_three_words ... ok
test tests::test_kebab_to_camel_auth ... ok

test result: ok. 4 passed
```

- [ ] **Step 5: Build and install binary**

```bash
cd scenario-gap && cargo build --release
cp target/release/scenario-gap ../bin/scenario-gap
```

- [ ] **Step 6: Smoke test**

In a repo with a `docs/domains/billing/test-scenarios.yaml`:

```bash
# No --new flag: check all scenarios
scenario-gap billing

# With --new flag: check only git-diff-new IDs
scenario-gap billing --new

# Missing file: should output []
scenario-gap nonexistent-domain
```

Expected: compact JSON array, exit 0.

- [ ] **Step 7: Commit**

```bash
git add scenario-gap/ bin/scenario-gap
git commit -m "feat: add scenario-gap Rust binary"
```

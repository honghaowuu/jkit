# Java Coding Standards Refactor — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the single generic `docs/java-coding-standards.md` with a Newland-stack-specific, multi-file ruleset under `docs/standards/`, gated by a per-project `docs/project-info.yaml` and selected by a new `jkit standards` CLI subcommand.

**Architecture:** Two-repo work. (1) Rust CLI in `/workspaces/jkit-cli` gains a `standards` subcommand (`list`, `list --explain`, `init`) that reads `docs/project-info.yaml` from the project, evaluates gates against rules shipped with the plugin, and prints applicable file paths. (2) Plugin repo at `/workspaces/jkit` gains 10 rule files under `docs/standards/`, a new index at `docs/java-coding-standards.md` (same path as before, content is now an applicability table + links), and a shipped `docs/project-info.schema.yaml` template. Three skills (`java-tdd`, `java-verify`, `scenario-tdd`) and five spec/plan docs have their "Step 0" wording updated.

**Tech Stack:** Rust 1.x with clap, serde, serde_yaml, anyhow, tempfile (already on jkit-cli). Markdown content authoring. No runtime/test framework changes.

**Spec reference:** `docs/superpowers/specs/2026-04-25-java-standards-refactor-design.md`

**Repo paths used in this plan:**
- `JKIT_CLI = /workspaces/jkit-cli` — Rust source
- `JKIT_PLUGIN = /workspaces/jkit` — plugin (docs, skills, pre-built binaries)
- `SOURCE_RULES = /workspaces/claude-plugin-java` — team's existing rule files (read-only source for extraction)

---

## File Structure

### New files in `JKIT_CLI` (Rust source)

- Create: `crates/jkit/src/standards/mod.rs` — `StandardsCmd` enum and dispatcher
- Create: `crates/jkit/src/standards/config.rs` — `ProjectInfo` struct, YAML loader
- Create: `crates/jkit/src/standards/gates.rs` — gate evaluation logic
- Create: `crates/jkit/src/standards/list.rs` — `list` and `list --explain` subcommands
- Create: `crates/jkit/src/standards/init.rs` — `init` subcommand (copy template)
- Create: `crates/jkit/tests/standards_integration.rs` — integration test
- Create: `crates/jkit/tests/fixtures/project-info-full.yaml` — fixture
- Create: `crates/jkit/tests/fixtures/project-info-minimal.yaml` — fixture
- Modify: `crates/jkit/src/lib.rs:1-7` — register `pub mod standards`
- Modify: `crates/jkit/src/main.rs:11-44` — wire `Standards` into the `Top` enum and dispatcher

### New files in `JKIT_PLUGIN` (plugin docs/skills)

- Create: `docs/project-info.schema.yaml`
- Create: `docs/standards/java-coding.md`
- Create: `docs/standards/api.md`
- Create: `docs/standards/exception.md`
- Create: `docs/standards/environment.md`
- Create: `docs/standards/database.md`
- Create: `docs/standards/tenant.md`
- Create: `docs/standards/i18n.md`
- Create: `docs/standards/redis.md`
- Create: `docs/standards/spring-cloud.md`
- Create: `docs/standards/auth-toms.md`
- Replace: `docs/java-coding-standards.md` (content becomes the index)
- Modify: `skills/java-tdd/SKILL.md` — Step 0 wording
- Modify: `skills/java-verify/SKILL.md` — Step 0 wording
- Modify: `skills/scenario-tdd/SKILL.md` — Step 0 wording
- Modify (citations only): `docs/superpowers/specs/2026-04-21-jkit-iter1-foundation.md`, `iter2-core-loop.md`, `iter3-quality-layer.md`
- Modify (citations only): `docs/superpowers/plans/2026-04-22-jkit-iter2-core-loop.md`, `iter3-quality-layer.md`
- Modify: `skills/migrate-project/SKILL.md` — ensure `docs/project-info.yaml` exists during migration
- Replace: `bin/jkit-linux-x86_64` (after `cargo build --release` of the new CLI)

---

## Phase 1 — CLI Implementation

### Task 1: Scaffold `standards` module wired into clap

**Files:**
- Create: `JKIT_CLI/crates/jkit/src/standards/mod.rs`
- Modify: `JKIT_CLI/crates/jkit/src/lib.rs`
- Modify: `JKIT_CLI/crates/jkit/src/main.rs`

- [ ] **Step 1: Create `standards/mod.rs` with the subcommand enum**

```rust
// crates/jkit/src/standards/mod.rs
use anyhow::Result;
use clap::Subcommand;

#[derive(Subcommand, Debug)]
pub enum StandardsCmd {
    /// Print the absolute paths of standards files that apply to this project.
    List {
        /// Show gate decisions next to each file.
        #[arg(long)]
        explain: bool,
    },
    /// Create docs/project-info.yaml from the shipped template if it does not exist.
    Init {
        /// Overwrite docs/project-info.yaml if it already exists.
        #[arg(long)]
        force: bool,
    },
}

pub fn run(cmd: StandardsCmd) -> Result<()> {
    match cmd {
        StandardsCmd::List { explain } => {
            anyhow::bail!("not implemented yet (Task 4 / 5)");
        }
        StandardsCmd::Init { force } => {
            anyhow::bail!("not implemented yet (Task 6)");
        }
    }
}
```

- [ ] **Step 2: Register the module in `lib.rs`**

Add after line 1 (`pub mod changes;`):

```rust
pub mod standards;
```

So the file becomes:

```rust
pub mod changes;
pub mod contract;
pub mod coverage;
pub mod migration;
pub mod pom;
pub mod scenarios;
pub mod standards;
pub mod util;
```

- [ ] **Step 3: Wire `Standards` into the `Top` enum and dispatcher in `main.rs`**

In the `Top` enum (after `Changes { ... }`):

```rust
    Standards {
        #[command(subcommand)]
        cmd: jkit::standards::StandardsCmd,
    },
```

In `fn main()`'s match (after `Top::Changes { cmd } => jkit::changes::run(cmd),`):

```rust
        Top::Standards { cmd } => jkit::standards::run(cmd),
```

- [ ] **Step 4: Build and verify the subcommand is registered**

```bash
cd /workspaces/jkit-cli && cargo build --release
./target/release/jkit standards --help
```

Expected: subcommand help shows `list` and `init`.

- [ ] **Step 5: Verify the stub errors as expected**

```bash
./target/release/jkit standards list
```

Expected: `error: not implemented yet (Task 4 / 5)` and exit code 1.

- [ ] **Step 6: Commit**

```bash
cd /workspaces/jkit-cli
git add crates/jkit/src/standards/mod.rs crates/jkit/src/lib.rs crates/jkit/src/main.rs
git commit -m "standards: scaffold CLI subcommand with stub list/init"
```

---

### Task 2: `ProjectInfo` struct + YAML loader (TDD)

**Files:**
- Create: `JKIT_CLI/crates/jkit/src/standards/config.rs`
- Create: `JKIT_CLI/crates/jkit/tests/fixtures/project-info-full.yaml`
- Create: `JKIT_CLI/crates/jkit/tests/standards_integration.rs`
- Modify: `JKIT_CLI/crates/jkit/src/standards/mod.rs` (register `pub mod config;`)

- [ ] **Step 1: Create the full-config fixture**

```yaml
# crates/jkit/tests/fixtures/project-info-full.yaml
project:
  name: my-app
  package: com.newland.myapp
  server-port: 3000

stack:
  java: 17
  spring-boot: 3.3.13
  mybatis-plus: 3.5.6

database:
  enabled: true
  type: mysql
  name: my_app_db

tenant:
  enabled: true

i18n:
  enabled: false
  languages: [zh, en]

redis:
  enabled: true

spring-cloud:
  enabled: false
  discovery:
    component: nacos

auth:
  toms:
    enabled: true
    api-version: 3.4.00-JDK17-SNAPSHOT

maven:
  repositories:
    - id: aliyun-repos
      url: https://maven.aliyun.com/repository/public
      snapshots: false
```

- [ ] **Step 2: Write failing test for `ProjectInfo::from_yaml_file`**

```rust
// crates/jkit/tests/standards_integration.rs
use jkit::standards::config::ProjectInfo;
use std::path::PathBuf;

fn fixture(name: &str) -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("tests/fixtures")
        .join(name)
}

#[test]
fn project_info_full_yaml_parses() {
    let info = ProjectInfo::from_yaml_file(&fixture("project-info-full.yaml"))
        .expect("parse full yaml");
    assert_eq!(info.project.name, "my-app");
    assert!(info.database.enabled);
    assert!(info.tenant.enabled);
    assert!(!info.i18n.enabled);
    assert!(info.redis.enabled);
    assert!(!info.spring_cloud.enabled);
    assert!(info.auth.toms.enabled);
}
```

- [ ] **Step 3: Run the test — it should fail to compile**

```bash
cd /workspaces/jkit-cli && cargo test --test standards_integration
```

Expected: compile error — `jkit::standards::config` does not exist.

- [ ] **Step 4: Implement `ProjectInfo` and the loader**

```rust
// crates/jkit/src/standards/config.rs
use anyhow::{Context, Result};
use serde::Deserialize;
use std::fs;
use std::path::Path;

#[derive(Debug, Deserialize)]
pub struct ProjectInfo {
    pub project: Project,
    #[serde(default)]
    pub stack: Stack,
    #[serde(default)]
    pub database: Database,
    #[serde(default)]
    pub tenant: Toggle,
    #[serde(default)]
    pub i18n: I18n,
    #[serde(default)]
    pub redis: Toggle,
    #[serde(default, rename = "spring-cloud")]
    pub spring_cloud: SpringCloud,
    #[serde(default)]
    pub auth: Auth,
    #[serde(default)]
    pub maven: Maven,
}

#[derive(Debug, Deserialize)]
pub struct Project {
    pub name: String,
    #[serde(default)]
    pub package: Option<String>,
    #[serde(default, rename = "server-port")]
    pub server_port: Option<u16>,
}

#[derive(Debug, Default, Deserialize)]
pub struct Stack {
    #[serde(default)]
    pub java: Option<u32>,
    #[serde(default, rename = "spring-boot")]
    pub spring_boot: Option<String>,
    #[serde(default, rename = "mybatis-plus")]
    pub mybatis_plus: Option<String>,
}

#[derive(Debug, Default, Deserialize)]
pub struct Database {
    #[serde(default)]
    pub enabled: bool,
    #[serde(default, rename = "type")]
    pub db_type: Option<String>,
    #[serde(default)]
    pub name: Option<String>,
}

#[derive(Debug, Default, Deserialize)]
pub struct Toggle {
    #[serde(default)]
    pub enabled: bool,
}

#[derive(Debug, Default, Deserialize)]
pub struct I18n {
    #[serde(default)]
    pub enabled: bool,
    #[serde(default)]
    pub languages: Vec<String>,
}

#[derive(Debug, Default, Deserialize)]
pub struct SpringCloud {
    #[serde(default)]
    pub enabled: bool,
}

#[derive(Debug, Default, Deserialize)]
pub struct Auth {
    #[serde(default)]
    pub toms: TomsAuth,
}

#[derive(Debug, Default, Deserialize)]
pub struct TomsAuth {
    #[serde(default)]
    pub enabled: bool,
    #[serde(default, rename = "api-version")]
    pub api_version: Option<String>,
}

#[derive(Debug, Default, Deserialize)]
pub struct Maven {
    #[serde(default)]
    pub repositories: Vec<MavenRepo>,
}

#[derive(Debug, Default, Deserialize)]
pub struct MavenRepo {
    pub id: String,
    pub url: String,
    #[serde(default)]
    pub snapshots: Option<bool>,
}

impl ProjectInfo {
    pub fn from_yaml_file(path: &Path) -> Result<Self> {
        let text = fs::read_to_string(path)
            .with_context(|| format!("reading {}", path.display()))?;
        let info: ProjectInfo = serde_yaml::from_str(&text)
            .with_context(|| format!("parsing {} as project-info.yaml", path.display()))?;
        Ok(info)
    }
}
```

- [ ] **Step 5: Register `config` in `standards/mod.rs`**

Add at the top of `mod.rs`:

```rust
pub mod config;
```

- [ ] **Step 6: Run the test — should pass**

```bash
cargo test --test standards_integration project_info_full_yaml_parses
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add crates/jkit/src/standards/config.rs crates/jkit/src/standards/mod.rs \
        crates/jkit/tests/standards_integration.rs \
        crates/jkit/tests/fixtures/project-info-full.yaml
git commit -m "standards: add ProjectInfo struct + YAML loader"
```

---

### Task 3: Gate evaluation (TDD)

**Files:**
- Create: `JKIT_CLI/crates/jkit/src/standards/gates.rs`
- Modify: `JKIT_CLI/crates/jkit/src/standards/mod.rs`
- Modify: `JKIT_CLI/crates/jkit/tests/standards_integration.rs`

- [ ] **Step 1: Write failing test for gate evaluation**

Append to `tests/standards_integration.rs`:

```rust
use jkit::standards::gates::{evaluate, GateOutcome, RuleFile};

#[test]
fn evaluate_full_fixture_returns_expected_outcomes() {
    let info = ProjectInfo::from_yaml_file(&fixture("project-info-full.yaml")).unwrap();
    let outcomes = evaluate(&info);

    let by_file: std::collections::HashMap<RuleFile, &GateOutcome> =
        outcomes.iter().map(|o| (o.file, o)).collect();

    assert!(matches!(by_file[&RuleFile::JavaCoding], GateOutcome { applies: true, .. }));
    assert!(matches!(by_file[&RuleFile::Api], GateOutcome { applies: true, .. }));
    assert!(matches!(by_file[&RuleFile::Exception], GateOutcome { applies: true, .. }));
    assert!(matches!(by_file[&RuleFile::Environment], GateOutcome { applies: true, .. }));
    assert!(matches!(by_file[&RuleFile::Database], GateOutcome { applies: true, .. }));
    assert!(matches!(by_file[&RuleFile::Tenant], GateOutcome { applies: true, .. }));
    assert!(matches!(by_file[&RuleFile::Redis], GateOutcome { applies: true, .. }));
    assert!(matches!(by_file[&RuleFile::AuthToms], GateOutcome { applies: true, .. }));
    assert!(matches!(by_file[&RuleFile::I18n], GateOutcome { applies: false, .. }));
    assert!(matches!(by_file[&RuleFile::SpringCloud], GateOutcome { applies: false, .. }));
}

#[test]
fn evaluate_outcomes_are_in_canonical_order() {
    let info = ProjectInfo::from_yaml_file(&fixture("project-info-full.yaml")).unwrap();
    let outcomes = evaluate(&info);
    let order: Vec<RuleFile> = outcomes.iter().map(|o| o.file).collect();
    assert_eq!(order, vec![
        RuleFile::JavaCoding,
        RuleFile::Api,
        RuleFile::Exception,
        RuleFile::Environment,
        RuleFile::Database,
        RuleFile::Tenant,
        RuleFile::I18n,
        RuleFile::Redis,
        RuleFile::SpringCloud,
        RuleFile::AuthToms,
    ]);
}
```

- [ ] **Step 2: Run the tests — should fail to compile**

```bash
cargo test --test standards_integration
```

Expected: `gates` module not found.

- [ ] **Step 3: Implement `gates.rs`**

```rust
// crates/jkit/src/standards/gates.rs
use crate::standards::config::ProjectInfo;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum RuleFile {
    JavaCoding,
    Api,
    Exception,
    Environment,
    Database,
    Tenant,
    I18n,
    Redis,
    SpringCloud,
    AuthToms,
}

impl RuleFile {
    pub fn relative_path(&self) -> &'static str {
        match self {
            RuleFile::JavaCoding  => "docs/standards/java-coding.md",
            RuleFile::Api         => "docs/standards/api.md",
            RuleFile::Exception   => "docs/standards/exception.md",
            RuleFile::Environment => "docs/standards/environment.md",
            RuleFile::Database    => "docs/standards/database.md",
            RuleFile::Tenant      => "docs/standards/tenant.md",
            RuleFile::I18n        => "docs/standards/i18n.md",
            RuleFile::Redis       => "docs/standards/redis.md",
            RuleFile::SpringCloud => "docs/standards/spring-cloud.md",
            RuleFile::AuthToms    => "docs/standards/auth-toms.md",
        }
    }

    pub fn short_name(&self) -> &'static str {
        match self {
            RuleFile::JavaCoding  => "java-coding.md",
            RuleFile::Api         => "api.md",
            RuleFile::Exception   => "exception.md",
            RuleFile::Environment => "environment.md",
            RuleFile::Database    => "database.md",
            RuleFile::Tenant      => "tenant.md",
            RuleFile::I18n        => "i18n.md",
            RuleFile::Redis       => "redis.md",
            RuleFile::SpringCloud => "spring-cloud.md",
            RuleFile::AuthToms    => "auth-toms.md",
        }
    }
}

#[derive(Debug)]
pub struct GateOutcome {
    pub file: RuleFile,
    pub applies: bool,
    /// One-line explanation, used by `--explain`. Examples:
    /// "always", "database.enabled=true", "spring-cloud.enabled=false".
    pub reason: String,
}

const CANONICAL_ORDER: &[RuleFile] = &[
    RuleFile::JavaCoding,
    RuleFile::Api,
    RuleFile::Exception,
    RuleFile::Environment,
    RuleFile::Database,
    RuleFile::Tenant,
    RuleFile::I18n,
    RuleFile::Redis,
    RuleFile::SpringCloud,
    RuleFile::AuthToms,
];

pub fn evaluate(info: &ProjectInfo) -> Vec<GateOutcome> {
    CANONICAL_ORDER.iter().map(|&file| {
        let (applies, reason) = match file {
            RuleFile::JavaCoding | RuleFile::Api | RuleFile::Exception | RuleFile::Environment => {
                (true, "always".to_string())
            }
            RuleFile::Database => (info.database.enabled, format!("database.enabled={}", info.database.enabled)),
            RuleFile::Tenant   => (info.tenant.enabled,   format!("tenant.enabled={}", info.tenant.enabled)),
            RuleFile::I18n     => (info.i18n.enabled,     format!("i18n.enabled={}", info.i18n.enabled)),
            RuleFile::Redis    => (info.redis.enabled,    format!("redis.enabled={}", info.redis.enabled)),
            RuleFile::SpringCloud => (info.spring_cloud.enabled, format!("spring-cloud.enabled={}", info.spring_cloud.enabled)),
            RuleFile::AuthToms => (info.auth.toms.enabled, format!("auth.toms.enabled={}", info.auth.toms.enabled)),
        };
        GateOutcome { file, applies, reason }
    }).collect()
}
```

- [ ] **Step 4: Register `gates` in `standards/mod.rs`**

```rust
pub mod config;
pub mod gates;
```

- [ ] **Step 5: Run tests — should pass**

```bash
cargo test --test standards_integration
```

Expected: 3 tests pass.

- [ ] **Step 6: Commit**

```bash
git add crates/jkit/src/standards/gates.rs crates/jkit/src/standards/mod.rs \
        crates/jkit/tests/standards_integration.rs
git commit -m "standards: add gate evaluation in canonical order"
```

---

### Task 4: `list` subcommand (no `--explain`)

**Files:**
- Create: `JKIT_CLI/crates/jkit/src/standards/list.rs`
- Modify: `JKIT_CLI/crates/jkit/src/standards/mod.rs`
- Modify: `JKIT_CLI/crates/jkit/tests/standards_integration.rs`

- [ ] **Step 1: Write failing test for `list`**

Append:

```rust
use std::process::Command;

fn jkit_bin() -> std::path::PathBuf {
    PathBuf::from(env!("CARGO_BIN_EXE_jkit"))
}

#[test]
fn list_prints_applicable_files_in_order() {
    let temp = tempfile::tempdir().unwrap();
    let project_dir = temp.path();
    std::fs::create_dir_all(project_dir.join("docs")).unwrap();
    std::fs::copy(
        fixture("project-info-full.yaml"),
        project_dir.join("docs/project-info.yaml"),
    ).unwrap();

    let plugin_root = temp.path().join("plugin");
    std::fs::create_dir_all(plugin_root.join("docs/standards")).unwrap();

    let output = Command::new(jkit_bin())
        .arg("standards").arg("list")
        .env("JKIT_PLUGIN_ROOT", &plugin_root)
        .current_dir(project_dir)
        .output()
        .expect("run jkit standards list");

    assert!(output.status.success(), "stderr: {}", String::from_utf8_lossy(&output.stderr));
    let stdout = String::from_utf8(output.stdout).unwrap();
    let lines: Vec<&str> = stdout.lines().collect();
    let expected = vec![
        plugin_root.join("docs/standards/java-coding.md").display().to_string(),
        plugin_root.join("docs/standards/api.md").display().to_string(),
        plugin_root.join("docs/standards/exception.md").display().to_string(),
        plugin_root.join("docs/standards/environment.md").display().to_string(),
        plugin_root.join("docs/standards/database.md").display().to_string(),
        plugin_root.join("docs/standards/tenant.md").display().to_string(),
        plugin_root.join("docs/standards/redis.md").display().to_string(),
        plugin_root.join("docs/standards/auth-toms.md").display().to_string(),
    ];
    assert_eq!(lines, expected);
}
```

Add `tempfile` to dev-dependencies if not already present (it is — `tempfile = "3"`).

- [ ] **Step 2: Run test — fails because `list` is still stubbed**

```bash
cargo test --test standards_integration list_prints_applicable_files_in_order
```

Expected: FAIL ("not implemented yet").

- [ ] **Step 3: Implement `list.rs`**

```rust
// crates/jkit/src/standards/list.rs
use anyhow::{Context, Result};
use std::env;
use std::path::PathBuf;

use crate::standards::config::ProjectInfo;
use crate::standards::gates::{evaluate, RuleFile};

pub fn run(explain: bool) -> Result<()> {
    let project_root = env::current_dir().context("getting current directory")?;
    let project_info_path = project_root.join("docs/project-info.yaml");
    if !project_info_path.exists() {
        anyhow::bail!(
            "missing {}\n  run `jkit standards init` to create it from the shipped template",
            project_info_path.display()
        );
    }
    let info = ProjectInfo::from_yaml_file(&project_info_path)?;
    let plugin_root = plugin_root()?;
    let outcomes = evaluate(&info);

    if explain {
        for o in &outcomes {
            let verb = if o.applies { "applies" } else { "skipped" };
            println!("{:<18} {} ({})", o.file.short_name(), verb, o.reason);
        }
    } else {
        for o in &outcomes {
            if o.applies {
                let path = plugin_root.join(o.file.relative_path());
                println!("{}", path.display());
            }
        }
    }
    Ok(())
}

fn plugin_root() -> Result<PathBuf> {
    if let Ok(v) = env::var("JKIT_PLUGIN_ROOT") {
        return Ok(PathBuf::from(v));
    }
    // Fallback: assume the binary lives in <plugin-root>/bin/.
    let exe = env::current_exe().context("locating jkit executable")?;
    let bin_dir = exe.parent().context("exe has no parent")?;
    let plugin_root = bin_dir.parent().context("bin dir has no parent")?;
    Ok(plugin_root.to_path_buf())
}
```

- [ ] **Step 4: Wire `list` in `standards/mod.rs`**

Replace the stub for `StandardsCmd::List`:

```rust
pub mod config;
pub mod gates;
pub mod list;

use anyhow::Result;
use clap::Subcommand;

#[derive(Subcommand, Debug)]
pub enum StandardsCmd {
    List {
        #[arg(long)]
        explain: bool,
    },
    Init {
        #[arg(long)]
        force: bool,
    },
}

pub fn run(cmd: StandardsCmd) -> Result<()> {
    match cmd {
        StandardsCmd::List { explain } => list::run(explain),
        StandardsCmd::Init { force: _ } => anyhow::bail!("not implemented yet (Task 6)"),
    }
}
```

- [ ] **Step 5: Run tests — should pass**

```bash
cargo test --test standards_integration
```

Expected: all pass including `list_prints_applicable_files_in_order`.

- [ ] **Step 6: Commit**

```bash
git add crates/jkit/src/standards/list.rs crates/jkit/src/standards/mod.rs \
        crates/jkit/tests/standards_integration.rs
git commit -m "standards: implement list (selects files via project-info.yaml gates)"
```

---

### Task 5: `list --explain` flag verification

**Files:**
- Modify: `JKIT_CLI/crates/jkit/tests/standards_integration.rs`

(Implementation is already in `list.rs` from Task 4; this task adds explicit test coverage for `--explain` output.)

- [ ] **Step 1: Write failing test for `--explain` output**

Append:

```rust
#[test]
fn list_explain_shows_gate_decisions() {
    let temp = tempfile::tempdir().unwrap();
    let project_dir = temp.path();
    std::fs::create_dir_all(project_dir.join("docs")).unwrap();
    std::fs::copy(
        fixture("project-info-full.yaml"),
        project_dir.join("docs/project-info.yaml"),
    ).unwrap();

    let output = Command::new(jkit_bin())
        .arg("standards").arg("list").arg("--explain")
        .env("JKIT_PLUGIN_ROOT", project_dir.join("plugin"))
        .current_dir(project_dir)
        .output()
        .expect("run jkit standards list --explain");

    assert!(output.status.success());
    let stdout = String::from_utf8(output.stdout).unwrap();
    assert!(stdout.contains("java-coding.md"));
    assert!(stdout.contains("applies (always)"));
    assert!(stdout.contains("i18n.md"));
    assert!(stdout.contains("skipped (i18n.enabled=false)"));
    assert!(stdout.contains("spring-cloud.md"));
    assert!(stdout.contains("skipped (spring-cloud.enabled=false)"));
    assert!(stdout.contains("auth-toms.md"));
    assert!(stdout.contains("applies (auth.toms.enabled=true)"));
}
```

- [ ] **Step 2: Run test — should pass**

```bash
cargo test --test standards_integration list_explain_shows_gate_decisions
```

Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add crates/jkit/tests/standards_integration.rs
git commit -m "standards: cover --explain output in integration test"
```

---

### Task 6: `init` subcommand

**Files:**
- Create: `JKIT_CLI/crates/jkit/src/standards/init.rs`
- Modify: `JKIT_CLI/crates/jkit/src/standards/mod.rs`
- Modify: `JKIT_CLI/crates/jkit/tests/standards_integration.rs`

- [ ] **Step 1: Write failing test**

Append:

```rust
#[test]
fn init_copies_template_to_docs_project_info_yaml() {
    let temp = tempfile::tempdir().unwrap();
    let project_dir = temp.path();
    let plugin_root = temp.path().join("plugin");
    std::fs::create_dir_all(plugin_root.join("docs")).unwrap();
    std::fs::write(
        plugin_root.join("docs/project-info.schema.yaml"),
        "project:\n  name: my-app\n",
    ).unwrap();

    let output = Command::new(jkit_bin())
        .arg("standards").arg("init")
        .env("JKIT_PLUGIN_ROOT", &plugin_root)
        .current_dir(project_dir)
        .output()
        .unwrap();

    assert!(output.status.success(), "stderr: {}", String::from_utf8_lossy(&output.stderr));
    let written = std::fs::read_to_string(project_dir.join("docs/project-info.yaml")).unwrap();
    assert!(written.contains("name: my-app"));
}

#[test]
fn init_refuses_to_overwrite_without_force() {
    let temp = tempfile::tempdir().unwrap();
    let project_dir = temp.path();
    std::fs::create_dir_all(project_dir.join("docs")).unwrap();
    std::fs::write(project_dir.join("docs/project-info.yaml"), "existing: true\n").unwrap();

    let plugin_root = temp.path().join("plugin");
    std::fs::create_dir_all(plugin_root.join("docs")).unwrap();
    std::fs::write(plugin_root.join("docs/project-info.schema.yaml"), "project:\n  name: x\n").unwrap();

    let output = Command::new(jkit_bin())
        .arg("standards").arg("init")
        .env("JKIT_PLUGIN_ROOT", &plugin_root)
        .current_dir(project_dir)
        .output()
        .unwrap();

    assert!(!output.status.success());
    let preserved = std::fs::read_to_string(project_dir.join("docs/project-info.yaml")).unwrap();
    assert_eq!(preserved, "existing: true\n");
}
```

- [ ] **Step 2: Run tests — should fail**

```bash
cargo test --test standards_integration init_
```

Expected: FAIL ("not implemented yet").

- [ ] **Step 3: Implement `init.rs`**

```rust
// crates/jkit/src/standards/init.rs
use anyhow::{Context, Result};
use std::env;
use std::fs;
use std::path::PathBuf;

pub fn run(force: bool) -> Result<()> {
    let project_root = env::current_dir().context("getting current directory")?;
    let dest = project_root.join("docs/project-info.yaml");

    if dest.exists() && !force {
        anyhow::bail!(
            "{} already exists; pass --force to overwrite",
            dest.display()
        );
    }

    let plugin_root = plugin_root()?;
    let template = plugin_root.join("docs/project-info.schema.yaml");
    if !template.exists() {
        anyhow::bail!(
            "shipped template missing: {}",
            template.display()
        );
    }

    if let Some(parent) = dest.parent() {
        fs::create_dir_all(parent).with_context(|| format!("creating {}", parent.display()))?;
    }
    fs::copy(&template, &dest)
        .with_context(|| format!("copying {} -> {}", template.display(), dest.display()))?;
    println!("created {}", dest.display());
    Ok(())
}

fn plugin_root() -> Result<PathBuf> {
    if let Ok(v) = env::var("JKIT_PLUGIN_ROOT") {
        return Ok(PathBuf::from(v));
    }
    let exe = env::current_exe()?;
    let bin_dir = exe.parent().context("exe has no parent")?;
    Ok(bin_dir.parent().context("bin dir has no parent")?.to_path_buf())
}
```

- [ ] **Step 4: Wire `init` in `standards/mod.rs`**

Replace the stub:

```rust
pub mod config;
pub mod gates;
pub mod init;
pub mod list;

// ... StandardsCmd as before ...

pub fn run(cmd: StandardsCmd) -> Result<()> {
    match cmd {
        StandardsCmd::List { explain } => list::run(explain),
        StandardsCmd::Init { force } => init::run(force),
    }
}
```

- [ ] **Step 5: Run all tests**

```bash
cargo test --test standards_integration
```

Expected: all pass.

- [ ] **Step 6: Commit**

```bash
git add crates/jkit/src/standards/init.rs crates/jkit/src/standards/mod.rs \
        crates/jkit/tests/standards_integration.rs
git commit -m "standards: implement init (copy schema template to docs/project-info.yaml)"
```

---

### Task 7: Missing-config error path

**Files:**
- Modify: `JKIT_CLI/crates/jkit/tests/standards_integration.rs`

(Behavior implemented in Task 4; this task adds an explicit test.)

- [ ] **Step 1: Write failing test**

Append:

```rust
#[test]
fn list_errors_clearly_when_project_info_missing() {
    let temp = tempfile::tempdir().unwrap();
    let project_dir = temp.path();
    let plugin_root = temp.path().join("plugin");
    std::fs::create_dir_all(plugin_root.join("docs/standards")).unwrap();

    let output = Command::new(jkit_bin())
        .arg("standards").arg("list")
        .env("JKIT_PLUGIN_ROOT", &plugin_root)
        .current_dir(project_dir)
        .output()
        .unwrap();

    assert!(!output.status.success());
    let stderr = String::from_utf8(output.stderr).unwrap();
    assert!(stderr.contains("project-info.yaml"));
    assert!(stderr.contains("jkit standards init"));
}
```

- [ ] **Step 2: Run — should pass (behavior already implemented in Task 4)**

```bash
cargo test --test standards_integration list_errors_clearly_when_project_info_missing
```

Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add crates/jkit/tests/standards_integration.rs
git commit -m "standards: cover missing-config error message in test"
```

---

## Phase 2 — Author Content Files in Plugin Repo

> **Working directory for the rest of this plan: `/workspaces/jkit`.**
>
> All content tasks below extract from `SOURCE_RULES = /workspaces/claude-plugin-java`. Each task names the source file(s) and the specific improvements (A=fix-bugs, B=add-checks, C=applicability-header, D=extract-to-yaml, E=dedupe) from the spec section "Content per File".

---

### Task 8: Ship `docs/project-info.schema.yaml`

**Files:**
- Create: `JKIT_PLUGIN/docs/project-info.schema.yaml`

- [ ] **Step 1: Write the canonical template**

Use the schema from the spec verbatim. Save to `docs/project-info.schema.yaml`:

```yaml
# jkit project info — copy to docs/project-info.yaml and customize.
# Fields with `enabled` flags gate which standards files apply.
# Run `jkit standards list --explain` to see active gates.

project:
  name: my-app                        # maven artifactId, log file name
  package: com.newland.myapp          # default: com.newland.{name}
  server-port: 3000                   # default: random 3000-3999

stack:
  java: 17
  spring-boot: 3.3.13
  mybatis-plus: 3.5.6

# gates standards/database.md
database:
  enabled: true
  type: mysql                         # only mysql supported
  name: my_app_db

# gates standards/tenant.md
# independent of auth.toms.enabled (a service can be multi-tenant
# without using TOMS — e.g. behind a gateway injecting tenant headers)
tenant:
  enabled: true

# gates standards/i18n.md
i18n:
  enabled: true
  languages: [zh, en, pt, ja]

# gates standards/redis.md
redis:
  enabled: true

# gates standards/spring-cloud.md (and all sub-modules)
spring-cloud:
  enabled: false
  discovery:
    component: nacos                  # nacos | eureka | consul | zookeeper
  config-center:
    enabled: true
    component: nacos
  circuit-breaker:
    enabled: true
    component: sentinel               # sentinel | resilience4j
  gateway:
    enabled: false

# gates standards/auth-toms.md
auth:
  toms:
    enabled: true
    api-version: 3.4.00-JDK17-SNAPSHOT

# referenced by standards/java-coding.md (Maven Repositories section)
maven:
  repositories:
    - id: aliyun-repos
      url: https://maven.aliyun.com/repository/public
      snapshots: false
    - id: maven-snapshots
      url: http://192.168.132.145:54002/nexus/repository/maven-snapshots/
```

- [ ] **Step 2: Verify the file parses with the CLI**

(After Phase 1 binary is in place — see Task 21. Skip this verification if running tasks strictly in order; come back after Task 21.)

- [ ] **Step 3: Commit**

```bash
cd /workspaces/jkit
git add docs/project-info.schema.yaml
git commit -m "docs: ship project-info schema template"
```

---

### Task 9: Replace `docs/java-coding-standards.md` with the new index

**Files:**
- Replace: `JKIT_PLUGIN/docs/java-coding-standards.md`

- [ ] **Step 1: Write the new index**

Overwrite `docs/java-coding-standards.md`:

```markdown
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
```

- [ ] **Step 2: Commit**

```bash
git add docs/java-coding-standards.md
git commit -m "docs: replace java-coding-standards with index pointing to standards/"
```

---

### Task 10: Author `docs/standards/java-coding.md`

**Files:**
- Create: `JKIT_PLUGIN/docs/standards/java-coding.md`

**Source:** `SOURCE_RULES/skills/generate/reference/java-coding-rule.md`

**Improvements to apply (per spec):**
- D extracted: Maven Repositories block reads from `project-info.yaml > maven.repositories`; remove inline URLs
- B added: Logging Checks section (see below)
- B added: Externalizing Configurable Values Checks
- Folded in from current generic doc: "one public class per file"; test method naming `methodName_scenarioDescription`

- [ ] **Step 1: Read source**

```bash
cat /workspaces/claude-plugin-java/skills/generate/reference/java-coding-rule.md
```

- [ ] **Step 2: Author the new file**

Structure (preserve the source's section order, apply improvements):

1. **Header**: `# Java Coding Standards (Always Applies)` + one-liner `**Applies always.**`
2. **Technology Stack** — values come from `project-info.yaml > stack`. Drop hard-coded versions; reference YAML keys.
3. **Package & Port** — derive from `project-info.yaml > project.package` and `server-port`. State the default rule.
4. **Layered Architecture** — verbatim.
5. **Method Constraints** — verbatim.
6. **One Class Per File** (folded in): "Each `.java` file MUST contain at most one public class."
7. **Comment Standards** — verbatim, including Javadoc layer table and key-step comment requirements.
8. **Large Data Handling** — verbatim.
9. **Spring Configuration** — verbatim.
10. **Externalizing Configurable Values** — verbatim, then add Checks subsection:
    ```markdown
    ### Checks
    - [ ] No `@Scheduled(cron = "<literal>")` in source — must use `${prop}` placeholder
    - [ ] No hardcoded timeout/retry/batch-size/threshold literals in Java source
    - [ ] No hardcoded URL prefixes, file paths, or bucket names in Java source
    ```
11. **Logging Configuration** — verbatim, then add Checks subsection:
    ```markdown
    ### Checks
    - [ ] `@Slf4j` annotation present on every class that logs (no manual `LoggerFactory.getLogger`)
    - [ ] No `System.out` / `System.err` calls in `src/`
    - [ ] `logback-spring.xml` exists; `logback.xml` does not
    - [ ] Log file path uses an env variable (e.g. `${LOG_PATH}`)
    - [ ] Rolling policy: daily, gz on >100MB, 30-day retention, 10 GB total
    - [ ] Log pattern includes timestamp, level, thread, logger, message
    ```
12. **DAO Model Rules** — *move to* `standards/database.md` (Task 13). Replace this section in `java-coding.md` with: "DAO/MyBatis-Plus rules → see [`database.md`](database.md)."
13. **Maven Repositories** — D extraction:
    ```markdown
    ## Maven Repositories

    Every generated `pom.xml` MUST include a `<repositories>` block whose entries come from `project-info.yaml > maven.repositories`. Apply each entry verbatim.

    **Placement:** inside `<project>`, after `</dependencies>` and before `<build>`.

    Example output (using the shipped template defaults):
    ```xml
    <repositories>
        <repository>
            <id>aliyun-repos</id>
            <url>https://maven.aliyun.com/repository/public</url>
            <snapshots><enabled>false</enabled></snapshots>
        </repository>
        <repository>
            <id>maven-snapshots</id>
            <url>http://192.168.132.145:54002/nexus/repository/maven-snapshots/</url>
        </repository>
    </repositories>
    ```
    ```
14. **Maven Commands** — verbatim.
15. **Testing** (folded in from current generic doc): "Test method naming: `methodName_scenarioDescription` (e.g., `createInvoice_withValidData_returns201`)."

- [ ] **Step 3: Verify cross-references**

```bash
grep -n "database.md\|api.md\|exception.md" docs/standards/java-coding.md
```

Expected: only the DAO cross-reference; no other accidental references.

- [ ] **Step 4: Commit**

```bash
git add docs/standards/java-coding.md
git commit -m "standards: author java-coding.md (extract from team rules + improvements)"
```

---

### Task 11: Author `docs/standards/api.md`

**Files:**
- Create: `JKIT_PLUGIN/docs/standards/api.md`

**Source:** `SOURCE_RULES/skills/generate/reference/api-rule.md`

**Improvements:** This file becomes the canonical home for "no try/catch in Controllers" and "global `@RestControllerAdvice`" — `exception.md` will cross-reference back here (E).

- [ ] **Step 1: Author**

Structure:

```markdown
# API Standards

**Applies always.**

## Standards
- Use standard HTTP verbs: GET, POST, PUT, DELETE
- Resource paths MUST be plural nouns (e.g., `/devices`, `/devices/{id}`)
- Return business data directly on success; MUST NOT wrap in a common response envelope
- List responses: `{ "items": [], "total": N }`
- Error format: `{ "code": <int>, "message": "<string>", "data": null }`
- ALL exceptions MUST be handled by a global `@RestControllerAdvice` (canonical home for this rule)
- Controllers MUST NOT catch exceptions directly (canonical home for this rule)
- Use `jakarta.validation` annotations: `@NotNull`, `@NotBlank`, `@Size`, `@Min`, `@Max`
- Validation errors MUST return the standard error response format

See [`exception.md`](exception.md) for the exception taxonomy and `ErrorCode` enum used inside the global handler.

## Checks
- [ ] No controller method wraps its return value in a response envelope
- [ ] List-returning endpoints return `{ "items": [...], "total": N }`
- [ ] One class annotated `@RestControllerAdvice` exists and handles all exceptions
- [ ] No try/catch blocks in any Controller class
- [ ] All request body parameters use `jakarta.validation` annotations
- [ ] `@Validated` present on all controller request body parameters
```

- [ ] **Step 2: Commit**

```bash
git add docs/standards/api.md
git commit -m "standards: author api.md (canonical home for advice/no-try-catch)"
```

---

### Task 12: Author `docs/standards/exception.md`

**Files:**
- Create: `JKIT_PLUGIN/docs/standards/exception.md`

**Source:** `SOURCE_RULES/skills/generate/reference/exception-rule.md`

**Improvements:**
- E: trim duplicate "no try/catch" / `@RestControllerAdvice` rules to cross-reference `api.md`
- B: add checks for `AppRtException` and `PermissionException` mapping

- [ ] **Step 1: Author**

```markdown
# Exception Handling Standards

**Applies always.**

## Exception Classification

Exception encapsulation is divided into the following four types; use as appropriate during code generation:

| Exception Type         | Description |
|------------------------|-------------|
| `AppBizException`      | Business exception: validation failure, business flow interruption |
| `AppRtException`       | Runtime exception: unknown system errors, NPE, illegal arguments |
| `PermissionException`  | Permission exception: permission check failure, access denied |
| `SQLException`         | SQL execution exception: catches unhandled database errors not intercepted by `AppBizException` |

The single global handler that maps these to HTTP responses lives in the class annotated `@RestControllerAdvice`. See [`api.md`](api.md) for the rule that this is the *only* place exceptions are caught.

## Global SQL Exception Handling

`SQLException` must be handled separately in the global exception handler:

```java
@ExceptionHandler(SQLException.class)
public Result<?> handleSqlException(SQLException e) {
    log.error("SQL execution error", e);
    return Result.fail(ErrorCode.DB_ERROR.getCode(), ErrorCode.DB_ERROR.getMessage(), null);
}
```

- This handler is at the outermost layer, catching all database exceptions not intercepted by `AppBizException`
- Full stack trace must be logged for troubleshooting

## Error Codes

All error codes MUST be defined in a single `ErrorCode` class/enum.

## Checks
- [ ] Every Service method that signals business failure throws `AppBizException`
- [ ] All error codes defined in a single `ErrorCode` class/enum
- [ ] Global handler has separate `@ExceptionHandler` for each of `AppBizException`, `AppRtException`, `PermissionException`, `SQLException`
- [ ] (cross-check `api.md`) No try/catch in any Controller class
```

- [ ] **Step 2: Commit**

```bash
git add docs/standards/exception.md
git commit -m "standards: author exception.md (taxonomy + handler; cross-ref api.md)"
```

---

### Task 13: Author `docs/standards/environment.md`

**Files:**
- Create: `JKIT_PLUGIN/docs/standards/environment.md`

**Source:** `SOURCE_RULES/rules/environment-rule.md`

**Improvements:** C (applicability header), B (gitignore + no-credentials checks).

- [ ] **Step 1: Author**

```markdown
# Environment Variable Standards

**Applies always.**

## Constraints

- MUST NOT hardcode host, port, username, or password anywhere in code
- All environment-dependent config (MySQL, Redis, MQ, service discovery) MUST come from environment variables

## Detection Priority

Check project root in this order:

1. `.env.dev.*` → use if found
2. `.env.test.*` → use if found
3. `.env.inte.*` → use if found
4. None found → MUST ask the user to supply config; MUST NOT assume defaults

This priority is referenced by [`spring-cloud.md`](spring-cloud.md), [`database.md`](database.md), and [`redis.md`](redis.md) for component server addresses.

## Checks
- [ ] No plaintext host / port / username / password in any `application*.yml`
- [ ] No plaintext host / port / username / password in any `*.java` source
- [ ] `.env.*` files listed in `.gitignore`
- [ ] No `.env.*` files committed to git
```

- [ ] **Step 2: Commit**

```bash
git add docs/standards/environment.md
git commit -m "standards: author environment.md"
```

---

### Task 14: Author `docs/standards/database.md`

**Files:**
- Create: `JKIT_PLUGIN/docs/standards/database.md`

**Sources:** `SOURCE_RULES/skills/db-schema/reference/mysql-rule.md` (primary) + DAO Model Rules from `java-coding-rule.md` (folded in here).

**Improvements:**
- A: drop the orphan `Before proceeding, read all files under '../generate/reference/'` line
- B: add comprehensive checks for ORM/table/column conventions
- C: applicability header

- [ ] **Step 1: Author**

Section structure:

1. Applicability header: `**Applies when:** `database.enabled: true` and `database.type: mysql` in `project-info.yaml`.`
2. **Database Operations** — verbatim from mysql-rule.md (CREATE DATABASE, USE, qualified table names). Replace `{database_name}` references with `project-info.yaml > database.name`.
3. **ORM** — verbatim (MyBatis-Plus only, `BaseMapper<T>`, forbidden annotations, XML mappers required, namespace matches DAO package).
4. **Table Naming** — `t_*` prefix.
5. **Column / Foreign-key** — never use foreign keys.
6. **Column / Type** — VARCHAR length matrix vs TEXT; reframe the "ask user when ambiguous" guidance as instruction to the model: "If a reasonable VARCHAR length cannot be inferred, ASK the user before generating; otherwise default to `VARCHAR(1024)` with a comment noting it can be tuned."
7. **Column / Primary Key** — `{entity}_id` for INT/BIGINT, `{entity}_uuid` for VARCHAR.
8. **Column / Audit (Required)** — `cre_time`, `cre_user_id`, `upd_time`, `upd_user_id` rules.
9. **Column / Nullability** — `NOT NULL` default; nullable columns must justify with comment.
10. **DAO Model Rules** (folded in from `java-coding-rule.md`):
    - `@TableField` annotation required for MySQL reserved words. Example: `@TableField("`desc`")`.
11. **SQL Rules** — no `SELECT *`; queries use indexed columns.
12. **Tenant Notes** — one-line cross-reference: "Multi-tenant column rules → see [`tenant.md`](tenant.md)."
13. **Checks**:
    ```markdown
    ## Checks
    - [ ] Every DAO interface extends `BaseMapper<T>`
    - [ ] No `@Select` / `@Insert` / `@Update` / `@Delete` annotation on any DAO method
    - [ ] Every XML mapper file's namespace matches the corresponding DAO interface package path
    - [ ] Every table name uses `t_*` prefix
    - [ ] Every `CREATE TABLE` is qualified as `{database_name}.{table_name}`
    - [ ] Every table has all four audit columns (`cre_time`, `cre_user_id`, `upd_time`, `upd_user_id`) when rows can be updated
    - [ ] No `FOREIGN KEY` clauses in any DDL
    - [ ] No `SELECT *` in any XML mapper or `LambdaQueryWrapper`
    - [ ] Every column declared `NOT NULL` unless its nullability is justified by a comment
    - [ ] Every MySQL-reserved-word column has `@TableField("\`name\`")` on its entity field
    - [ ] No `VARCHAR` field longer than 4000 without a comment justifying TEXT/LONGTEXT instead
    ```

- [ ] **Step 2: Commit**

```bash
git add docs/standards/database.md
git commit -m "standards: author database.md (mysql + mybatis-plus + dao model)"
```

---

### Task 15: Author `docs/standards/tenant.md` (with translation)

**Files:**
- Create: `JKIT_PLUGIN/docs/standards/tenant.md`

**Source:** `SOURCE_RULES/skills/db-schema/reference/tenant-rule.md` (Chinese — translate to English).

**Improvements:**
- C: applicability header
- B: add comprehensive checks
- Translate from Chinese to English; preserve identifier values (`ADMIN`/`OPERATOR`/`MERCHANT`/`DEV`) verbatim
- This file is the canonical home for the `character_code`/`key_id` identity scheme; cross-references from `redis.md` and `auth-toms.md` will point here

- [ ] **Step 1: Author (English translation)**

Section outline (translate the prose, keep all SQL/XML/Java code blocks verbatim):

1. **Applies when:** `tenant.enabled: true` in `project-info.yaml`. Independent of `auth.toms.enabled`.
2. **Tenant Identity** — Two-field combination `character_code` + `key_id`. Show the field table (translate descriptions to English). Show the `character_code` enum table with English descriptions, e.g.:
   - `ADMIN` — System administrator, manages all tenants
   - `OPERATOR` — Operator: an enterprise that has purchased services or device products
   - `MERCHANT` — Merchant: a physical merchant
   - `DEV` — ISV: independent software vendor
3. **Which Tables Need Tenant Columns**:
   - **Required:** business primary tables (entities natively belonging to a tenant); denormalized child tables (copy tenant fields from parent to avoid JOINs)
   - **Not required:** system dictionaries (globally shared enums/configs); pure M:N junction tables; system log tables
   - **Decision rule:** if a record naturally belongs to a tenant, the table needs the tenant columns
4. **Column Definitions** — verbatim SQL example (translate Chinese comments to English). Rules: both `character_code` (VARCHAR(32) NOT NULL) and `key_id` (BIGINT NOT NULL); both must always appear together; comments may stay bilingual (English description + Chinese enum list).
5. **Index Conventions**:
   - Main table: composite `(character_code, key_id, status)` and unique `(character_code, key_id, {field})`. Field order: `character_code` first (highest selectivity), then `key_id`, then other filters.
   - Denormalized child table: required `idx_{table}_{fk_column}`. Composite tenant index optional unless the child is queried directly by tenant.
6. **Multi-tenant Query Rules**:
   - Main table: explicit `WHERE character_code = #{...} AND key_id = #{...}`
   - Child via FK: `WHERE template_id = #{...}` — tenant isolation inherited
   - Forbidden: bare `SELECT * FROM ...` without tenant filter; child-table queries that bypass FK
   - Uniqueness checks must include tenant filter
7. **Denormalized Child Tenant Field Assignment** — values come from the parent record, not from `UserContext`.
8. **Complete DDL Example** — verbatim (translate comments).
9. **Checks**:
   ```markdown
   ## Checks
   - [ ] Every business main table has both `character_code` (VARCHAR(32) NOT NULL) and `key_id` (BIGINT NOT NULL)
   - [ ] No table has only one of the two columns
   - [ ] Every business main table has a composite index starting with `(character_code, key_id, ...)`
   - [ ] Every uniqueness query (find-by-name, find-by-code, etc.) includes `character_code` and `key_id` in the predicate
   - [ ] Denormalized child tables copy `character_code`/`key_id` from the parent record, not from `UserContext`
   - [ ] No main-table query lacks a tenant filter
   ```

- [ ] **Step 2: Commit**

```bash
git add docs/standards/tenant.md
git commit -m "standards: author tenant.md (translated, canonical for character_code/key_id)"
```

---

### Task 16: Author `docs/standards/i18n.md`

**Files:**
- Create: `JKIT_PLUGIN/docs/standards/i18n.md`

**Source:** `SOURCE_RULES/skills/generate/reference/i18n-rule.md`

**Improvements:** C (applicability header), B (cross-language-file consistency check).

- [ ] **Step 1: Author**

```markdown
# Internationalization Standards

**Applies when:** `i18n.enabled: true` in `project-info.yaml`.

The set of supported languages comes from `project-info.yaml > i18n.languages`. The default template ships `[zh, en, pt, ja]`.

## Standards
- ALL messages returned to the frontend MUST use i18n keys; no hardcoded strings
- For every language `L` in `i18n.languages`, a file `messages_{L}.properties` MUST exist on the resource path
- Keys: lowercase letters, dot-separated (e.g., `device.not.found`)
- Keys MUST be identical across all language files
- NEVER modify or remove existing keys
- New keys MUST be added to ALL configured language files simultaneously
- Resolve language from `Accept-Language` header; fallback to system default if absent

## Checks
- [ ] No hardcoded user-facing string in Controller / Service responses
- [ ] Every language `L` in `i18n.languages` has a `messages_{L}.properties` file
- [ ] Every key is present in *every* configured language file (no missing translations)
- [ ] No existing key has been modified or removed
```

- [ ] **Step 2: Commit**

```bash
git add docs/standards/i18n.md
git commit -m "standards: author i18n.md"
```

---

### Task 17: Author `docs/standards/redis.md`

**Files:**
- Create: `JKIT_PLUGIN/docs/standards/redis.md`

**Source:** `SOURCE_RULES/skills/generate/reference/redis-rule.md`

**Improvements:** C (applicability header). Cross-reference `tenant.md` for the identity scheme.

- [ ] **Step 1: Author**

```markdown
# Redis Standards

**Applies when:** `redis.enabled: true` in `project-info.yaml`.

## Standards

### Key Naming

A tenant is identified by the combination of `character_code` + `key_id` — see [`tenant.md`](tenant.md) for the canonical identity scheme.

| Scope  | Key Format                                  | Example                    |
|--------|---------------------------------------------|----------------------------|
| Global | `{entity}`                                  | `config:all`               |
| Tenant | `{character_code}:{key_id}:{entity}`        | `CORP_A:K001:device:all`   |
| User   | `{character_code}:{key_id}:{user_id}:{entity}` | `CORP_A:K001:U007:session` |

### Expiry
- ALL cached objects MUST have an expiry (default: 24 hours)
- Large-data caches: MUST add a risk comment in code noting the data size concern

## Checks
- [ ] Every Redis write sets a TTL
- [ ] No Redis key is a bare entity name without scope prefix (unless explicitly Global scope)
- [ ] Tenant-scoped keys include both `character_code` and `key_id`
- [ ] User-scoped keys include `character_code`, `key_id`, and `user_id`
- [ ] Large-data caches have a risk comment
```

- [ ] **Step 2: Commit**

```bash
git add docs/standards/redis.md
git commit -m "standards: author redis.md"
```

---

### Task 18: Author `docs/standards/spring-cloud.md`

**Files:**
- Create: `JKIT_PLUGIN/docs/standards/spring-cloud.md`

**Source:** `SOURCE_RULES/skills/generate/reference/spring-cloud-rule.md`

**Improvements:**
- C: replace bespoke "Pre-Flight Check" with the standard applicability header
- E: trim duplicated env-file detection prose; cross-reference `environment.md`
- D: defaults table moves to `project-info.yaml > spring-cloud.{module}.default-address`; standards file says "use the env-file address; if absent, fall back to the default-address from `project-info.yaml`"

- [ ] **Step 1: Author**

Section outline:

1. **Applies when:** `spring-cloud.enabled: true` in `project-info.yaml`. Each sub-module additionally checks its own `enabled`. If the top-level flag is `false`, all sub-modules are skipped regardless.
2. **Env File Convention** — short. State that env-file detection priority is defined in [`environment.md`](environment.md). This file owns the *variable name table* per component:

   | Component  | File pattern              | Variables                                              |
   |------------|---------------------------|--------------------------------------------------------|
   | nacos      | `.env.{env}.nacos`        | `NACOS_SERVER_ADDR`, `NACOS_NAMESPACE`, `NACOS_GROUP`  |
   | eureka     | `.env.{env}.eureka`       | `EUREKA_DEFAULT_ZONE`                                  |
   | consul     | `.env.{env}.consul`       | `CONSUL_HOST`, `CONSUL_PORT`                           |
   | zookeeper  | `.env.{env}.zookeeper`    | `ZOOKEEPER_CONNECT_STRING`                             |
   | sentinel   | `.env.{env}.sentinel`     | `SENTINEL_DASHBOARD_ADDR`                              |

   If the env file is missing: ask the user (per `environment.md`); if the user declines, fall back to `project-info.yaml > spring-cloud.{module}.default-address` if present.

3. **Module: Discovery (Required when top-level enabled)** — verbatim prose.
4. **Module: Config Center (Optional)** — verbatim, with applicability gate `config-center.enabled: true`.
5. **Module: Circuit Breaker (Optional)** — verbatim, with applicability gate `circuit-breaker.enabled: true`.
6. **Module: Gateway (Optional)** — verbatim, with applicability gate `gateway.enabled: true`. When gateway is enabled, this service does not implement auth — see [`auth-toms.md`](auth-toms.md) gating.
7. **Checks** — verbatim.

- [ ] **Step 2: Commit**

```bash
git add docs/standards/spring-cloud.md
git commit -m "standards: author spring-cloud.md (cross-ref environment.md, defaults to yaml)"
```

---

### Task 19: Author `docs/standards/auth-toms.md`

**Files:**
- Create: `JKIT_PLUGIN/docs/standards/auth-toms.md`

**Source:** `SOURCE_RULES/skills/generate/reference/toms-authorization-rule.md`

**Improvements:**
- A fixed: §2 register `PlatformWebAuthInterceptor` (not `UserContextInterceptor` — that was the source bug)
- A fixed: standardize on `StringRedisTemplate` throughout (source mixed `RedisTemplate<String,Object>` and `StringRedisTemplate`)
- D extracted: `authorization-api-version` reads from `project-info.yaml > auth.toms.api-version`; no embedded default

- [ ] **Step 1: Author**

Sections:

1. **Applies when:** `auth.toms.enabled: true` in `project-info.yaml`.
2. **Maven Dependency**:
   ```markdown
   Add to `pom.xml`. Version comes from `project-info.yaml > auth.toms.api-version`:

   ```xml
   <dependency>
       <groupId>com.newland.modules</groupId>
       <artifactId>authorization-api</artifactId>
       <version>${authorization-api-version}</version>
   </dependency>
   ```

   Declare `<authorization-api-version>` in `<properties>` with the value from `project-info.yaml`.
   ```
3. **PlatformWebAuthInterceptor — Registration** (FIX A):
   ```java
   @Configuration
   public class WebMvcConfig implements WebMvcConfigurer {

       private final StringRedisTemplate redisTemplate;

       public WebMvcConfig(StringRedisTemplate redisTemplate) {
           this.redisTemplate = redisTemplate;
       }

       @Override
       public void addInterceptors(InterceptorRegistry registry) {
           registry.addInterceptor(new PlatformWebAuthInterceptor())
                   .addPathPatterns("/**");
           registry.addInterceptor(new UserContextInterceptor(redisTemplate))
                   .addPathPatterns("/**");
       }
   }
   ```
   Note: `PlatformWebAuthInterceptor` validates `@Permission` annotations on every request. Do NOT add `excludePathPatterns` unless the API explicitly requires public access.
4. **UserContextInterceptor — User Info Extraction** — keep the source code block verbatim (it already uses `StringRedisTemplate` correctly). Drop the trailing "Register **after** `PlatformWebAuthInterceptor`" snippet — registration is now consolidated in §3.
5. **UserContext — Thread-Local Store** — verbatim, including the prohibition on mock fallback.
6. **@Permission Annotation — Generation Flow** — verbatim, including the decision tree, tenant→CharacterEnum mapping, and the six annotation patterns (5.1–5.6). Cross-reference `tenant.md` for the identity scheme.
7. **PowerConst — Function Permission Constants** — verbatim. Add header note: "Example values (`124012.MANAGE`, etc.) are illustrations only. Real codes come from `docs/domains/*/api-implement-logic.md` per project."
8. **Prohibitions** — verbatim production + test prohibitions.
9. **Checks** — verbatim.

- [ ] **Step 2: Verify the bug fix is applied**

```bash
grep -n "PlatformWebAuthInterceptor\|UserContextInterceptor" docs/standards/auth-toms.md
```

Expected: §3 (Registration) creates `PlatformWebAuthInterceptor` first, `UserContextInterceptor` second. No mention of `RedisTemplate<String, Object>`.

- [ ] **Step 3: Commit**

```bash
git add docs/standards/auth-toms.md
git commit -m "standards: author auth-toms.md (fix interceptor bug, extract version to yaml)"
```

---

## Phase 3 — Wire It In

### Task 20: Build CLI release and copy to plugin's `bin/`

**Files:**
- Replace: `JKIT_PLUGIN/bin/jkit-linux-x86_64` (and other platform binaries if available)

- [ ] **Step 1: Build the release binary**

```bash
cd /workspaces/jkit-cli
cargo build --release
```

Expected: `target/release/jkit` produced.

- [ ] **Step 2: Verify the new subcommand works against the new schema file**

```bash
cd /workspaces/jkit
mkdir -p /tmp/jkit-smoke/docs
cp /workspaces/jkit/docs/project-info.schema.yaml /tmp/jkit-smoke/docs/project-info.yaml
JKIT_PLUGIN_ROOT=/workspaces/jkit /workspaces/jkit-cli/target/release/jkit standards list --explain
# Run from the smoke dir:
cd /tmp/jkit-smoke && JKIT_PLUGIN_ROOT=/workspaces/jkit /workspaces/jkit-cli/target/release/jkit standards list
```

Expected: list of 9 absolute paths (all 10 except `spring-cloud.md`, since the shipped template defaults `spring-cloud.enabled: false`).

- [ ] **Step 3: Replace the platform binary**

```bash
cp /workspaces/jkit-cli/target/release/jkit /workspaces/jkit/bin/jkit-linux-x86_64
chmod +x /workspaces/jkit/bin/jkit-linux-x86_64
/workspaces/jkit/bin/jkit standards --help
```

Expected: help text shows `list` and `init` subcommands.

- [ ] **Step 4: Commit**

```bash
cd /workspaces/jkit
git add bin/jkit-linux-x86_64
git commit -m "bin: rebuild jkit with standards subcommand"
```

> Note: only the linux-x86_64 binary is rebuilt here. Other platform binaries (`jkit-darwin-*`, `jkit-windows-*`) need separate builds — out of scope unless the user provides them.

---

### Task 21: Update `skills/java-tdd/SKILL.md` Step 0

**Files:**
- Modify: `JKIT_PLUGIN/skills/java-tdd/SKILL.md`

- [ ] **Step 1: Read current Step 0**

```bash
grep -n "Load java-coding-standards\|coding-standards" /workspaces/jkit/skills/java-tdd/SKILL.md
```

Hits at lines 23, 37, 53, 76, 116. Lines 23 and 76 are the prose step; 37/53 are graphviz nodes/edges; 116 is a deeper subagent reference.

- [ ] **Step 2: Update line 23 (checklist)**

Replace:
```
- [ ] Load java-coding-standards
```
with:
```
- [ ] Load standards (run `jkit standards list`, read every file printed)
```

- [ ] **Step 3: Update line 37 (graphviz node)**

Replace:
```
    "Load java-coding-standards" [shape=box];
```
with:
```
    "Load standards (jkit standards list)" [shape=box];
```

- [ ] **Step 4: Update line 53 (graphviz edge)**

Replace:
```
    "Load java-coding-standards" -> "kit plan-status";
```
with:
```
    "Load standards (jkit standards list)" -> "kit plan-status";
```

- [ ] **Step 5: Update line 76 (Step 0 prose)**

Replace:
```
**Step 0 — Load java-coding-standards.** Read `<plugin-root>/docs/java-coding-standards.md`.
```
with:
```
**Step 0 — Load standards.** Run `jkit standards list` from the project root and read every file it prints. Apply all rules. (If the command errors with a missing-config message, run `jkit standards init` first to create `docs/project-info.yaml`.)
```

- [ ] **Step 6: Update line 116 (subagent embedding reference)**

Replace `the java-coding-standards reference` with `the standards reference (the file set printed by jkit standards list)`.

- [ ] **Step 7: Verify no remaining `java-coding-standards` mentions**

```bash
grep -n "java-coding-standards" /workspaces/jkit/skills/java-tdd/SKILL.md
```

Expected: no output.

- [ ] **Step 8: Commit**

```bash
git add skills/java-tdd/SKILL.md
git commit -m "skills/java-tdd: switch Step 0 to jkit standards list"
```

---

### Task 22: Update `skills/java-verify/SKILL.md` Step 0

**Files:**
- Modify: `JKIT_PLUGIN/skills/java-verify/SKILL.md`

(Same pattern as Task 21. Lines: 14 checklist, 25 graphviz node, 38 graphviz edge, 57 Step 0 prose.)

- [ ] **Step 1: Apply equivalent edits to lines 14, 25, 38, 57**

Use the same replacement strings as Task 21 steps 2/3/4/5, adjusted for the local edge target (`-> "jkit pom --profile quality --apply"`).

- [ ] **Step 2: Verify clean**

```bash
grep -n "java-coding-standards" /workspaces/jkit/skills/java-verify/SKILL.md
```

Expected: no output.

- [ ] **Step 3: Commit**

```bash
git add skills/java-verify/SKILL.md
git commit -m "skills/java-verify: switch Step 0 to jkit standards list"
```

---

### Task 23: Update `skills/scenario-tdd/SKILL.md` Step 0

**Files:**
- Modify: `JKIT_PLUGIN/skills/scenario-tdd/SKILL.md`

(Lines: 25 checklist, 35 graphviz node, 46 graphviz edge, 62 Step 0 prose.)

- [ ] **Step 1: Apply equivalent edits**

Use the same replacement strings as Task 21, adjusted for the local edge target (`-> "jkit scenarios prereqs --apply"`).

- [ ] **Step 2: Verify clean**

```bash
grep -n "java-coding-standards" /workspaces/jkit/skills/scenario-tdd/SKILL.md
```

Expected: no output.

- [ ] **Step 3: Commit**

```bash
git add skills/scenario-tdd/SKILL.md
git commit -m "skills/scenario-tdd: switch Step 0 to jkit standards list"
```

---

### Task 24: Mechanically update spec/plan citations

**Files:**
- Modify: `docs/superpowers/specs/2026-04-21-jkit-iter1-foundation.md`
- Modify: `docs/superpowers/specs/2026-04-21-jkit-iter2-core-loop.md`
- Modify: `docs/superpowers/specs/2026-04-21-jkit-iter3-quality-layer.md`
- Modify: `docs/superpowers/plans/2026-04-22-jkit-iter2-core-loop.md`
- Modify: `docs/superpowers/plans/2026-04-22-jkit-iter3-quality-layer.md`

These are historical iteration specs/plans. Update citations only — do not rewrite the iter docs themselves.

- [ ] **Step 1: For each file, replace "Load java-coding-standards" → "Load standards (jkit standards list)"**

```bash
cd /workspaces/jkit
for f in \
  docs/superpowers/specs/2026-04-21-jkit-iter1-foundation.md \
  docs/superpowers/specs/2026-04-21-jkit-iter2-core-loop.md \
  docs/superpowers/specs/2026-04-21-jkit-iter3-quality-layer.md \
  docs/superpowers/plans/2026-04-22-jkit-iter2-core-loop.md \
  docs/superpowers/plans/2026-04-22-jkit-iter3-quality-layer.md
do
  echo "== $f =="
  grep -n "java-coding-standards" "$f"
done
```

- [ ] **Step 2: Apply edits per file**

For each occurrence:
- Checklist `- [ ] Load java-coding-standards` → `- [ ] Load standards (jkit standards list)`
- Graphviz node `"Load java-coding-standards"` → `"Load standards (jkit standards list)"`
- Step prose `Read \`<plugin-root>/docs/java-coding-standards.md\`. Apply all rules.` → `Run \`jkit standards list\` and read every file it prints. Apply all rules.`

(Use Edit tool per file; the strings appear multiple times — use `replace_all` for the canonical forms once they match exactly.)

- [ ] **Step 3: Verify clean across all five files**

```bash
grep -rn "java-coding-standards" docs/superpowers/specs/2026-04-21-* docs/superpowers/plans/2026-04-22-*
```

Expected: no output.

- [ ] **Step 4: Commit**

```bash
git add docs/superpowers/specs/2026-04-21-*.md docs/superpowers/plans/2026-04-22-*.md
git commit -m "docs: update iter spec/plan citations to jkit standards list"
```

---

### Task 25: Wire `migrate-project` to ensure `project-info.yaml` exists

**Files:**
- Modify: `JKIT_PLUGIN/skills/migrate-project/SKILL.md`

- [ ] **Step 1: Find the right insertion point**

```bash
grep -n "init\|project-info\|step\|Step" /workspaces/jkit/skills/migrate-project/SKILL.md | head -30
```

Locate the section where the skill bootstraps project artifacts (e.g., where it would already create or check for `docs/`).

- [ ] **Step 2: Add a step**

Insert a step (using exact heading style of the surrounding skill) that runs:

```bash
if [ ! -f docs/project-info.yaml ]; then
  jkit standards init
fi
```

Then asks the user to review and customize `docs/project-info.yaml` (set `spring-cloud.enabled`, `i18n.enabled`, etc., according to their project) before proceeding.

- [ ] **Step 3: Commit**

```bash
git add skills/migrate-project/SKILL.md
git commit -m "skills/migrate-project: ensure docs/project-info.yaml exists"
```

---

### Task 26: End-to-end smoke test

**Files:** none — verification only

- [ ] **Step 1: Set up a fresh smoke directory**

```bash
rm -rf /tmp/jkit-e2e && mkdir -p /tmp/jkit-e2e && cd /tmp/jkit-e2e
```

- [ ] **Step 2: Confirm missing-config error path**

```bash
JKIT_PLUGIN_ROOT=/workspaces/jkit /workspaces/jkit/bin/jkit standards list
```

Expected: error mentioning `docs/project-info.yaml` and `jkit standards init`, exit 1.

- [ ] **Step 3: Run init**

```bash
JKIT_PLUGIN_ROOT=/workspaces/jkit /workspaces/jkit/bin/jkit standards init
ls docs/
cat docs/project-info.yaml | head
```

Expected: `docs/project-info.yaml` exists, mirroring the shipped template.

- [ ] **Step 4: Run list**

```bash
JKIT_PLUGIN_ROOT=/workspaces/jkit /workspaces/jkit/bin/jkit standards list
```

Expected: 9 absolute paths, each pointing to an existing file under `/workspaces/jkit/docs/standards/`. Verify each printed path exists:

```bash
JKIT_PLUGIN_ROOT=/workspaces/jkit /workspaces/jkit/bin/jkit standards list | xargs -n1 ls -l
```

Expected: every path resolves; no "No such file or directory".

- [ ] **Step 5: Run list --explain**

```bash
JKIT_PLUGIN_ROOT=/workspaces/jkit /workspaces/jkit/bin/jkit standards list --explain
```

Expected: 10 lines covering every rule file. Always-applies show `applies (always)`. Conditionals show `applies (X.enabled=true)` or `skipped (X.enabled=false)` matching the template defaults (`spring-cloud.enabled: false` → spring-cloud.md skipped; everything else applies).

- [ ] **Step 6: Toggle a flag and re-run**

```bash
sed -i 's/^  enabled: false$/  enabled: true/' docs/project-info.yaml  # flip spring-cloud
JKIT_PLUGIN_ROOT=/workspaces/jkit /workspaces/jkit/bin/jkit standards list --explain | grep spring-cloud
```

Expected: now shows `applies (spring-cloud.enabled=true)`.

- [ ] **Step 7: Restore the smoke dir doesn't pollute jkit**

```bash
cd /workspaces/jkit && git status
```

Expected: clean (no changes spilled into the plugin repo).

(Smoke test is verification only; nothing to commit.)

---

## Self-Review

Spec coverage check:

- ✅ File layout (10 files + index + schema YAML) — Tasks 8, 9, 10–19
- ✅ `project-info.yaml` schema — Task 8
- ✅ `jkit standards list` CLI subcommand — Tasks 1, 4
- ✅ `jkit standards list --explain` — Task 5
- ✅ `jkit standards init` — Task 6
- ✅ Missing-config error path — Tasks 4, 7
- ✅ Skill Step 0 wording updates — Tasks 21, 22, 23
- ✅ Spec/plan citation updates — Task 24
- ✅ `migrate-project` ensures `project-info.yaml` exists — Task 25
- ✅ Smoke test — Task 26
- ✅ Improvement A (auth interceptor bug fix; mysql-rule orphan; redis-template type) — Tasks 14, 19
- ✅ Improvement B (strengthened checks for logging, externalized values, exception mapping, env, database, tenant, i18n) — Tasks 10, 12, 13, 14, 15, 16
- ✅ Improvement C (applicability headers) — Tasks 13, 14, 15, 16, 17, 18, 19
- ✅ Improvement D (extract URLs/version to yaml) — Tasks 8, 10, 18, 19
- ✅ Improvement E (dedupe controller-advice/try-catch) — Tasks 11, 12

Placeholder scan: each content-authoring task references the source file and lists concrete improvements; no "TBD" or "implement later" remains. The complete code for each CLI step is included; content tasks describe the exact section structure, header text, and check-list contents to author.

Type consistency check: `RuleFile`, `GateOutcome`, `ProjectInfo` field names used in Task 3's tests match the definitions in Tasks 2/3. CLI flag names (`--explain`, `--force`) and env var (`JKIT_PLUGIN_ROOT`) are consistent across all tasks that reference them.

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-04-25-java-standards-refactor.md`. Two execution options:

1. **Subagent-Driven (recommended)** — Dispatch a fresh subagent per task, review between tasks, fast iteration. Best for the 26 tasks here since they split cleanly across two repos and have natural review checkpoints (after each phase).

2. **Inline Execution** — Execute tasks in this session with batch checkpoints. Reasonable if you want to review the CLI changes as they happen.

Which approach?

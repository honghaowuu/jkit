---
name: install-contracts
description: Use when setting up upstream service dependencies, or when adding a new microservice dependency to the current project.
---

**Announcement:** At start: *"I'm using the install-contracts skill to install service contract dependencies."*

## Checklist

- [ ] Read `contracts.json` at repo root — if missing, ask which services to depend on, create it; if present, offer to append new entries before proceeding
- [ ] Read `.jkit/contract.json` for `marketplaceRepo`, `marketplaceName` — if missing, ask once, save
- [ ] Register marketplace if not already registered: `claude plugin marketplace add {marketplaceRepo}`
- [ ] Refresh marketplace index: `claude plugin marketplace update {marketplaceName}`
- [ ] Clone marketplace, read `.claude-plugin/marketplace.json`, write `.jkit/marketplace-catalog.json`, delete clone
- [ ] For each dependency: `claude plugin install {service-name} --scope local`
- [ ] Warn if any service name is not found in marketplace
- [ ] Confirm installed plugins are available; note that a new Claude session may be required for plugins to activate
- [ ] Commit `contracts.json` + `.jkit/marketplace-catalog.json` + `.jkit/contract.json` to the consumer repo

## Process Flow

```dot
digraph install_contracts {
    "Read contracts.json" [shape=box];
    "contracts.json exists?" [shape=diamond];
    "Ask which services to depend on\ncreate contracts.json" [shape=box];
    "Offer to append\nnew entries?" [shape=diamond];
    "Ask which services to add\nappend to contracts.json" [shape=box];
    "Read .jkit/contract.json\n(ask for missing fields)" [shape=box];
    "claude plugin marketplace add\n{marketplaceRepo}" [shape=box];
    "claude plugin marketplace update\n{marketplaceName}" [shape=box];
    "Clone marketplace\nwrite .jkit/marketplace-catalog.json\ndelete clone" [shape=box];
    "For each dependency:\nclaude plugin install {name}\n--scope local" [shape=box];
    "All installed?" [shape=diamond];
    "Warn: not found in marketplace\nlist them" [shape=box];
    "Commit contracts.json\n+ catalog + .jkit/contract.json\nnote: new session may be needed" [shape=doublecircle];

    "Read contracts.json" -> "contracts.json exists?";
    "contracts.json exists?" -> "Ask which services to depend on\ncreate contracts.json" [label="no"];
    "contracts.json exists?" -> "Offer to append\nnew entries?" [label="yes"];
    "Offer to append\nnew entries?" -> "Ask which services to add\nappend to contracts.json" [label="yes"];
    "Offer to append\nnew entries?" -> "Read .jkit/contract.json\n(ask for missing fields)" [label="no"];
    "Ask which services to add\nappend to contracts.json" -> "Read .jkit/contract.json\n(ask for missing fields)";
    "Ask which services to depend on\ncreate contracts.json" -> "Read .jkit/contract.json\n(ask for missing fields)";
    "Read .jkit/contract.json\n(ask for missing fields)" -> "claude plugin marketplace add\n{marketplaceRepo}";
    "claude plugin marketplace add\n{marketplaceRepo}" -> "claude plugin marketplace update\n{marketplaceName}";
    "claude plugin marketplace update\n{marketplaceName}" -> "Clone marketplace\nwrite .jkit/marketplace-catalog.json\ndelete clone";
    "Clone marketplace\nwrite .jkit/marketplace-catalog.json\ndelete clone" -> "For each dependency:\nclaude plugin install {name}\n--scope local";
    "For each dependency:\nclaude plugin install {name}\n--scope local" -> "All installed?";
    "All installed?" -> "Warn: not found in marketplace\nlist them" [label="partial"];
    "All installed?" -> "Commit contracts.json\n+ catalog + .jkit/contract.json\nnote: new session may be needed" [label="yes"];
    "Warn: not found in marketplace\nlist them" -> "Commit contracts.json\n+ catalog + .jkit/contract.json\nnote: new session may be needed";
}
```

## Commands Reference

Individual commands used by the flow above:

```bash
# Register marketplace (idempotent)
claude plugin marketplace add {marketplaceRepo}

# Refresh index (called after registering)
claude plugin marketplace update {marketplaceName}

# Install one dependency
claude plugin install {service-name} --scope local
```

`--scope local` installs into the project's `.claude/settings.json`. Use `--scope user` only if the developer wants a contract globally available across all projects.

Note: `bin/marketplace-sync.sh` combines the `marketplace update` call + catalog write in one step. Do not call it in addition to the explicit flow steps — it would duplicate the `update` call.

## `contracts.json` Format

Lives at the **repo root** of a consumer microservice (alongside `pom.xml`). Created by `install-contracts` on first run if absent:

```json
{
  "dependencies": ["{service-name}", "{service-name-2}"]
}
```

When `contracts.json` already exists, `install-contracts` offers to append new entries before proceeding. Committed to the service repo — treat it like `pom.xml`.

## `.jkit/contract.json` Format

Persists marketplace configuration. `install-contracts` writes only `marketplaceRepo` and `marketplaceName`. `contractRepo` is written only by `publish-contract` (publisher side):

```json
{
  "marketplaceRepo": "git@github.com:{org}/marketplace.git",
  "marketplaceName": "{org}-marketplace"
}
```

Ask for these two fields once, then persist. If `publish-contract` has already run in this repo, `contractRepo` will also be present — leave it untouched.

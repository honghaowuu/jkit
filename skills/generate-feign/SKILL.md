---
name: generate-feign
description: Use when you need to generate a Feign client for an upstream microservice. Requires the service's contract plugin to be installed.
---

**Announcement:** At start: *"I'm using the generate-feign skill to generate a Feign client from the {service-name} contract."*

## Checklist

- [ ] Identify target service from task context
- [ ] Confirm contract plugin is installed (`/{service-name}` skill available)
- [ ] Invoke `/{service-name}` skill to navigate to the right API (levels 1→4)
- [ ] Check SKILL.md for `## SDK` section — if present, offer SDK dependency instead of generating
- [ ] Read `reference/contract.yaml` for the target path(s)
- [ ] Determine generation scope — if not clear from task context, ask: full client or scoped to specific paths/tags?
- [ ] Generate Feign client in `feign/` package
- [ ] Write integration test scaffold

## Process Flow

```dot
digraph generate_feign {
    "Identify target service\nfrom task context" [shape=box];
    "Contract plugin installed?" [shape=diamond];
    "Stop: run install-contracts first" [shape=box];
    "Invoke /{service-name} skill\nnavigate to right API" [shape=box];
    "SDK declared in SKILL.md?" [shape=diamond];
    "Offer: use SDK dependency\ninstead of generating" [shape=box];
    "Human chooses SDK?" [shape=diamond];
    "Add SDK to pom.xml\nskip generation" [shape=doublecircle];
    "Determine scope\n(full or scoped)" [shape=diamond];
    "Ask: full or scoped?" [shape=box];
    "Read reference/contract.yaml\nfor target paths" [shape=box];
    "Generate Feign client\nin feign/ package" [shape=box];
    "Write integration test scaffold" [shape=doublecircle];

    "Identify target service\nfrom task context" -> "Contract plugin installed?";
    "Contract plugin installed?" -> "Stop: run install-contracts first" [label="no"];
    "Contract plugin installed?" -> "Invoke /{service-name} skill\nnavigate to right API" [label="yes"];
    "Invoke /{service-name} skill\nnavigate to right API" -> "SDK declared in SKILL.md?";
    "SDK declared in SKILL.md?" -> "Offer: use SDK dependency\ninstead of generating" [label="yes"];
    "SDK declared in SKILL.md?" -> "Determine scope\n(full or scoped)" [label="no"];
    "Offer: use SDK dependency\ninstead of generating" -> "Human chooses SDK?";
    "Human chooses SDK?" -> "Add SDK to pom.xml\nskip generation" [label="yes"];
    "Human chooses SDK?" -> "Determine scope\n(full or scoped)" [label="no, generate anyway"];
    "Determine scope\n(full or scoped)" -> "Ask: full or scoped?" [label="ambiguous"];
    "Determine scope\n(full or scoped)" -> "Read reference/contract.yaml\nfor target paths" [label="clear"];
    "Ask: full or scoped?" -> "Read reference/contract.yaml\nfor target paths";
    "Read reference/contract.yaml\nfor target paths" -> "Generate Feign client\nin feign/ package";
    "Generate Feign client\nin feign/ package" -> "Write integration test scaffold";
}
```

## Contract Plugin Location

Installed plugins are resolved by Claude Code's plugin system. Read contract files relative to the plugin root:

```
skills/{service-name}/             ← SKILL.md (already loaded when skill is invoked)
domains/{domain-name}.md           ← Level 3 — read on demand
reference/contract.yaml            ← Level 4 — grepped for target paths
```

## Generation Rules

- Feign client goes in `src/main/java/{group-path}/feign/{ServiceName}Client.java`
- One interface per service (not one per domain)
- If SDK module exists (declared in SKILL.md `## SDK`): offer the SDK dependency first — confirm with human before generating
- Scoped generation: only include paths matching the specified prefix or tag
- Integration test scaffold goes in `src/test/java/{group-path}/feign/{ServiceName}ClientTest.java`

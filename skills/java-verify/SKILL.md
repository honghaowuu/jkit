---
name: java-verify
description: Use when verifying all quality gates and coverage after scenario-tdd completes, or when explicitly asked to run the full verification suite.
---

**Announcement:** At start: *"I'm using the java-verify skill to run quality gates and coverage checks."*

## Skill Type: Technique/Pattern

## Checklist

- [ ] Load java-coding-standards
- [ ] Ensure quality plugins
- [ ] Run mvn verify
- [ ] Check merged JaCoCo coverage
- [ ] Check API endpoint coverage
- [ ] Fix failures or note gaps
- [ ] Invoke requesting-code-review

## Process Flow

```dot
digraph java_verify {
    "Load java-coding-standards" [shape=box];
    "Ensure quality plugins\n(Checkstyle/PMD/SpotBugs)" [shape=box];
    "mvn verify" [shape=box];
    "jkit coverage (merged jacoco)\njkit coverage --api" [shape=box];
    "Failures?" [shape=diamond];
    "Fix inline" [shape=box];
    "Gaps only?" [shape=diamond];
    "Ask: fix now or note for review" [shape=box];
    "superpowers:requesting-code-review" [shape=doublecircle];

    "Load java-coding-standards" -> "Ensure quality plugins\n(Checkstyle/PMD/SpotBugs)";
    "Ensure quality plugins\n(Checkstyle/PMD/SpotBugs)" -> "mvn verify";
    "mvn verify" -> "jkit coverage (merged jacoco)\njkit coverage --api";
    "jkit coverage (merged jacoco)\njkit coverage --api" -> "Failures?";
    "Failures?" -> "Fix inline" [label="yes"];
    "Fix inline" -> "mvn verify";
    "Failures?" -> "Gaps only?" [label="no"];
    "Gaps only?" -> "Ask: fix now or note for review" [label="yes"];
    "Gaps only?" -> "superpowers:requesting-code-review" [label="no"];
    "Ask: fix now or note for review" -> "superpowers:requesting-code-review";
}
```

## Detailed Flow

**Step 0: Load java-coding-standards**

Read `<plugin-root>/docs/java-coding-standards.md`. Apply all rules.

**Step 1: Ensure quality plugins**

Check `pom.xml` for Checkstyle, PMD, SpotBugs. If missing:
> "Quality plugins not found.
> A) Add from templates/pom-fragments/quality.xml (recommended)
> B) Skip quality gate"

On A: add fragment. Note in final commit message.

**Step 2: Run mvn verify**

```bash
JKIT_ENV=test direnv exec . mvn verify
```

Runs: unit tests → quality gates → integration tests (Failsafe) → JaCoCo dump + merge + report.

Fix failures inline. Repeat until green.

**Step 3: Coverage check**

```bash
# Unit + integration combined (merged jacoco.xml)
bin/jkit coverage target/site/jacoco/jacoco.xml --summary --min-score 1.0

# API endpoint coverage: spec vs test source
bin/jkit coverage --api docs/domains/ src/test/java/
```

**Failures** (tests or quality): fix inline, re-run.

**Gaps only** (coverage below threshold or untested endpoints): ask:
> "Coverage gaps found: [list].
> A) Fix gaps now — run scenario-tdd / add unit tests (recommended)
> B) Proceed to code review — I'll note the gaps"

**Step 4: Code review handoff**

java-verify does NOT own the final commit. The commit is `java-tdd`'s responsibility.

**REQUIRED SUB-SKILL: invoke `superpowers:requesting-code-review`.**

## Superpowers Integration

| Superpowers skill | How used |
|---|---|
| `superpowers:requesting-code-review` | Always — final step after all checks pass |

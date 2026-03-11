# Planning File Templates

## When to Use Interactive Planning

**Use this skill for:**
- Multi-step tasks (3+ steps)
- Tasks with unclear requirements
- Tasks with multiple valid approaches
- Research projects
- Anything needing user alignment

**Skip for:**
- Simple questions
- Single-file edits
- Tasks with crystal-clear requirements

## Template Locations

Located at `~/.claude/skills/planning-with-files/templates/`:
- `task_plan.md`
- `findings.md`
- `progress.md`

---

## findings.md Template

**Task-based mode** — use this template as-is.
**Spec-driven mode** — use this template WITH the spec-driven sections (marked below).

```markdown
# Findings & Decisions

## Goal
[One sentence from Gate 2]

## Priority
[From Gate 1: Speed/Quality/Flexibility/Simplicity]

## Mode
[task-based | spec-driven]

## Approach
[From Gate 3 with rationale]

## Requirements
[From Gate 2 - validated by user]

<!-- SPEC-DRIVEN ONLY: include the sections below -->

## Spec Map
→ Manifest: docs/plans/manifest.md
→ Specs directory: docs/plans/specs/

### Dependency DAG
{Copy the Mermaid graph from manifest.md here — single source of truth for /orchestrate}

### Per-Spec Decisions
| Spec | Key Decision | Rationale | Affects |
|------|-------------|-----------|---------|
| {spec-name} | {decision made during Gate 3} | {why} | {downstream specs impacted} |

## Sprint Grouping
| Sprint | Specs | Can Parallelize |
|--------|-------|-----------------|
| Phase 1, Sprint 1 | {specs} | yes/no |
| Phase 1, Sprint 2 | {specs} | yes/no |

<!-- END SPEC-DRIVEN ONLY -->

## Research Findings
-

## Technical Decisions
| Decision | Rationale |
|----------|-----------|
| [From Gate 3] | [Why chosen] |

## Visual/Browser Findings
<!-- Update after every 2 view/browser operations -->
-
```

---

## progress.md Template

**Task-based mode** — use this template without the spec sections.
**Spec-driven mode** — include the Spec Status table (the primary resume signal for `/orchestrate --resume`).

```markdown
# Progress Log

## Session: [DATE]

<!-- SPEC-DRIVEN ONLY -->
## Spec Status
| Spec | Phase | Sprint | Status | Commit | Last Updated |
|------|-------|--------|--------|--------|-------------|
| {spec-name} | {N} | {M} | draft | — | {date} |

<!-- Status values: draft → in_progress → completed | blocked | skipped -->
<!-- Commit column: filled by /orchestrate after merge (enables git-log resume recovery) -->
<!-- END SPEC-DRIVEN ONLY -->

### Phase 1: [Title]
- **Status:** in_progress
- **Started:** [timestamp]
- Actions taken:
- Files created/modified:

## Test Results
| Test | Expected | Actual | Status |
|------|----------|--------|--------|

## 5-Question Reboot Check
| Question | Answer |
|----------|--------|
| Where am I? | Phase X, Sprint Y |
| Where am I going? | Remaining phases/specs |
| What's the goal? | [goal] |
| What have I learned? | findings.md |
| What have I done? | See above |
```

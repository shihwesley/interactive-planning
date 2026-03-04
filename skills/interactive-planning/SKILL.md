---
name: interactive-planning
description: "File-based planning with interactive gates and native task tracking. Use when starting complex multi-step tasks, projects with unclear requirements, tasks with multiple valid approaches, or research projects. Supports task-based (single plan file) and spec-driven (multi-file specs with manifest) modes. Phase/Sprint/Spec hierarchy with dependency DAG. Plans are categorized (feat/fix/refactor/review/test/polish/general) and stored in docs/plans/{category}/{name}/. Triggers on: 'plan this', 'let me think through this', 'break this down', 'create a plan', 'spec this out', 'what should the approach be'."
---

# Interactive Planning (Manus + AskUserQuestion)

Combines **file-based persistence** (Manus-style) with **interactive clarification gates**.

## Core Philosophy

```
Context Window = RAM (volatile, limited)
Filesystem = Disk (persistent, unlimited)
Task Tools = Structured progress (visible, stateful)
AskUserQuestion = User alignment (prevents rework)

> Tasks for actions (TaskCreate/Update)
> Files for knowledge (findings.md)
> Ask users before committing to approaches
```

## Plan Directory Structure

Each planning session lives in its own directory under `docs/plans/{category}/{plan-name}/`:

```
docs/plans/
  feat/auth-system/           # new feature plan
    manifest.md               # (spec-driven) or task_plan.md (task-based)
    specs/                    # (spec-driven only)
    findings.md
    progress.md
  fix/login-crash/            # bug fix plan
    task_plan.md
    findings.md
    progress.md
  general/app-architecture/   # whole-app planning
    manifest.md
    specs/
    findings.md
    progress.md
```

**Categories:** `general`, `feat`, `fix`, `refactor`, `review`, `test`, `polish`

All file references below use `{PLAN_DIR}` which resolves to `docs/plans/{category}/{plan-name}`.

---

## Phase 0: Session Recovery

**Before anything else**, scan for existing planning sessions:

```bash
# Scan categorized plan directories
find docs/plans -maxdepth 3 \( -name manifest.md -o -name task_plan.md \) 2>/dev/null
# Also check legacy flat paths (pre-v5 plans)
ls task_plan.md findings.md progress.md docs/plans/manifest.md 2>/dev/null
```

**If multiple plans found:**
1. List all plans with their category, name, and mode (spec-driven vs task-based)
2. Ask the user which plan to resume:
```python
AskUserQuestion(
  question="Found multiple planning sessions. Which one to resume?",
  header="Resume",
  options=[
    # One option per discovered plan, e.g.:
    {"label": "feat/auth-system", "description": "Spec-driven, Phase 1 Sprint 2, 3/7 specs done"},
    {"label": "fix/login-crash", "description": "Task-based, Phase 2, 4/6 tasks done"},
    {"label": "Start new plan", "description": "Begin a fresh planning session"}
  ]
)
```

**If single plan found:**
1. `git diff --stat` to see code changes since last session
2. Read existing planning files from that plan's directory
3. Check TaskList for existing tasks
4. Update files and task statuses based on context
5. Then proceed from where you left off

**If legacy flat-path files found** (task_plan.md at project root or docs/plans/manifest.md without category subdirectory):
1. Treat as a pre-v5 plan — resume from existing paths without migrating
2. On next `/interactive-planning reset`, these files will be cleaned up

---

## Phase 0.5: Auto-detect Plan Category + Name

Before Gate 1, analyze the user's initial request to auto-classify the plan.

**Category detection heuristics** (match against user's description):

| Keywords / signals | Category |
|---|---|
| fix, bug, crash, broken, error, issue, regression | `fix` |
| test, coverage, unit test, integration, spec test, QA | `test` |
| refactor, restructure, rewrite, migrate, modernize, rename, extract | `refactor` |
| review, audit, assess, evaluate, check, inspect, analyze quality | `review` |
| polish, improve UX, animation, performance, accessibility, a11y, perf | `polish` |
| architecture, bootstrap, scaffold, whole app, project setup, general plan | `general` |
| Default (new functionality, add, create, build, implement) | `feat` |

**Plan name derivation:**
1. Extract the key noun phrase from the user's description
2. Slugify: lowercase, hyphens for spaces, strip special characters, max 40 chars
3. Examples: "Plan the authentication system" → `auth-system`, "Fix the login crash on iOS 18" → `login-crash-ios18`

Set:
```
PLAN_CATEGORY = {detected category}
PLAN_NAME = {derived slug}
PLAN_DIR = docs/plans/{PLAN_CATEGORY}/{PLAN_NAME}
```

Display to user before Gate 1:
```
Plan: {PLAN_CATEGORY}/{PLAN_NAME}
Directory: docs/plans/{PLAN_CATEGORY}/{PLAN_NAME}/
```

The user can correct this at Gate 1 via "Other" if the auto-detection is wrong.

---

## Phase 1: Interactive Requirements Gathering

### Gate 1: Planning Mode + Priority

Use AskUserQuestion BEFORE creating any files. Two questions:

**Question 1: Planning Mode**
```python
AskUserQuestion(
  question="What kind of planning does this need? (Plan: {PLAN_CATEGORY}/{PLAN_NAME})",
  header="Mode",
  options=[
    {"label": "Task-based (Recommended)", "description": "Single task_plan.md with phases. Best for straightforward features."},
    {"label": "Spec-driven", "description": "Multiple spec files per concern, manifest index. Best for complex multi-domain work."}
  ]
)
```

If "Task-based" -> continue with existing flow (Gates 2-4 unchanged).
If "Spec-driven" -> continue with Gates 2, 3 (enhanced), 4 (enhanced) below.

Note: The detected plan category/name is shown in the question text. If the user selects "Other" and provides a different category or name, update `PLAN_CATEGORY`, `PLAN_NAME`, and `PLAN_DIR` accordingly.

**Question 2: Priority** (asked regardless of mode)
```python
AskUserQuestion(
  question="Which aspect is most important?",
  header="Priority",
  options=[
    {"label": "Speed (Recommended)", "description": "MVP approach, ship fast, iterate later"},
    {"label": "Quality", "description": "Tests, docs, edge cases, production-ready"},
    {"label": "Flexibility", "description": "Extensible, configurable, multiple use cases"},
    {"label": "Simplicity", "description": "Minimal, focused, easy to understand"}
  ]
)
```

### Gate 2: Requirements Validation

```python
AskUserQuestion(
  question="I identified these requirements. Select all that apply:",
  header="Requirements",
  multiSelect=True,
  options=[
    {"label": "[Inferred req 1]", "description": "..."},
    {"label": "[Inferred req 2]", "description": "..."},
    {"label": "[Inferred req 3]", "description": "..."},
    {"label": "Add more", "description": "I'll provide additional requirements"}
  ]
)
```

### Gate 3: Approach Decision (Task-Based Mode)

```python
AskUserQuestion(
  question="There are a few ways to approach this:",
  header="Approach",
  options=[
    {"label": "Approach A", "description": "Tradeoffs: faster but less flexible"},
    {"label": "Approach B", "description": "Tradeoffs: more setup but scalable"},
    {"label": "Approach C", "description": "Tradeoffs: full control, more work"}
  ]
)
```

### Gate 3 (Spec-Driven): Approach + Spec Decomposition

If spec-driven mode was selected in Gate 1, replace Gate 3 above with this combined gate:

1. Analyze requirements from Gate 2
2. Propose an architectural approach
3. Decompose into spec files with dependency relationships
4. Auto-compute sprint/phase grouping via topological sort of dependency DAG
5. Present everything together for user validation

Present to user:

```
Based on your requirements, here's the approach and spec breakdown:

**Approach:** {description of chosen approach with rationale}

**Spec Decomposition:**
- root-spec.md -- {description} (parent of all)
  +-- {name}-spec.md -- {description}
  +-- {name}-spec.md -- {description} (depends on: {dep})
  +-- {name}-spec.md -- {description} (depends on: {dep})

**Auto-computed grouping:**
Phase 1, Sprint 1: root-spec, {independent specs}
Phase 1, Sprint 2: {specs depending on sprint 1}
Phase 2, Sprint 1: {specs depending on phase 1}
```

```python
AskUserQuestion(
  question="Does this spec breakdown look right?",
  header="Specs",
  options=[
    {"label": "Looks good", "description": "Proceed with this decomposition"},
    {"label": "Adjust specs", "description": "I want to add, remove, or restructure specs"},
    {"label": "Too granular", "description": "Merge some specs together"},
    {"label": "Not granular enough", "description": "Split some specs further"}
  ]
)
```

**Sprint/Phase auto-assignment algorithm:**
1. Topological sort of spec dependency DAG
2. Specs with no unmet dependencies -> same sprint
3. Specs whose deps are all in earlier sprints -> next sprint
4. Sprint groups -> phases (one phase per dependency "level")
5. User can override at Gate 4

---

## Phase 2: Create Tasks and Files

After gates pass, create the plan directory and **tasks** for phases and **files** for research.

```bash
mkdir -p {PLAN_DIR}
```

### Task-Based Mode: Create Tasks + Files

Create `{PLAN_DIR}/task_plan.md` with the plan content, then create tasks for each phase:

```python
# Phase 1
TaskCreate(
  subject="Phase 1: [Title]",
  description="Plan: {PLAN_CATEGORY}/{PLAN_NAME}\n[Details from gates]\n- Task 1\n- Task 2",
  activeForm="Working on Phase 1"
)

# Phase 2 (blocked by Phase 1)
TaskCreate(
  subject="Phase 2: [Title]",
  description="Plan: {PLAN_CATEGORY}/{PLAN_NAME}\n[Details]",
  activeForm="Working on Phase 2"
)
# Then: TaskUpdate(taskId="2", addBlockedBy=["1"])
```

### Spec-Driven Mode: Create Manifest + Spec Files + Tasks

#### Step 1: Create specs/ directory

```bash
mkdir -p {PLAN_DIR}/specs
```

#### Step 2: Generate manifest.md

Use the manifest template at `${CLAUDE_PLUGIN_ROOT}/skills/interactive-planning/templates/manifest-template.md`.

Fill in:
- Project name, date, mode ("spec-driven"), priority from Gate 1
- Category and plan name from Phase 0.5
- Dependency graph (Mermaid) from Gate 3 decomposition
- Phase/Sprint/Spec map from auto-assignment
- Spec files table with paths and approximate line counts

Write to: `{PLAN_DIR}/manifest.md`

#### Step 3: Generate individual spec files

For each spec from Gate 3, use the template at
`${CLAUDE_PLUGIN_ROOT}/skills/interactive-planning/templates/spec-template.md`.

Fill in:
- YAML frontmatter: name, phase, sprint, parent, depends_on, status=draft, created date
- Requirements: distribute Gate 2 requirements to relevant specs
- Acceptance criteria: testable criteria derived from requirements
- Technical approach: from Gate 3
- Files: inferred from codebase structure or project conventions
- Tasks: 2-5 per spec, derived from requirements
- Dependencies: what it needs from upstream, what it provides downstream

Write each to: `{PLAN_DIR}/specs/{name}-spec.md`

#### Step 4: Create findings.md (spec-driven enhanced)

Use the spec-driven findings.md template below (not the task-based version).
Write to: `{PLAN_DIR}/findings.md`

#### Step 5: Create progress.md (spec-driven enhanced)

Use the spec-driven progress.md template below.
Write to: `{PLAN_DIR}/progress.md`

#### Step 6: Create two-level TaskCreate entries

Create tasks at two levels: **spec tasks** (parents) and **sub-tasks** (from the spec's Tasks section).

**Level 1 -- Spec tasks (inter-spec blocking via DAG):**

```python
# Create one parent task per spec
TaskCreate(
  subject="Spec: {spec-name}",
  description="Plan: {PLAN_CATEGORY}/{PLAN_NAME}\nImplement {PLAN_DIR}/specs/{spec-name}-spec.md\nPhase {N}, Sprint {M}\nDepends on: {deps}\n\nParent task. Sub-tasks below do the actual work.",
  activeForm="Implementing {spec-name}"
)

# Wire inter-spec dependencies from the DAG
# If api-spec depends on data-model-spec:
TaskUpdate(taskId="{api-spec-task}", addBlockedBy=["{data-model-spec-task}"])
```

**Level 2 -- Sub-tasks (intra-spec, sequential within each spec):**

For each task listed in the spec's `## Tasks` section, create a sub-task
that references its parent spec and is blocked by the previous sub-task:

```python
# Sub-task 1
TaskCreate(
  subject="data-model: Create database schema",
  description="Plan: {PLAN_CATEGORY}/{PLAN_NAME}\nSpec: data-model (Phase 1, Sprint 1)\nParent task: #{spec_task_id}",
  activeForm="Creating database schema"
)
TaskUpdate(taskId="1a", addBlockedBy=["{upstream_spec_last_subtask}"])

# Sub-task 2 -- blocked by sub-task 1
TaskCreate(
  subject="data-model: Write migration",
  description="Plan: {PLAN_CATEGORY}/{PLAN_NAME}\nSpec: data-model (Phase 1, Sprint 1)\nParent task: #{spec_task_id}",
  activeForm="Writing migration"
)
TaskUpdate(taskId="1b", addBlockedBy=["1a"])
```

**Inter-spec handoff:** A downstream spec's first sub-task is blocked by the upstream spec's **last** sub-task (not the parent), so work actually finishes before the next spec starts.

**Naming:** Sub-task subjects are prefixed with their spec name (`data-model: Create schema`) to keep the flat task list readable.

**Completion:** When all sub-tasks for a spec complete, mark the parent spec task completed too.

Then continue to Gate 4 below.

### Create findings.md

**Task-based mode** -- use the base template.
**Spec-driven mode** -- use the base template WITH the spec-driven sections.
Write to: `{PLAN_DIR}/findings.md`

```markdown
# Findings & Decisions

## Plan
- **Category:** {PLAN_CATEGORY}
- **Name:** {PLAN_NAME}
- **Directory:** {PLAN_DIR}

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
> Manifest: {PLAN_DIR}/manifest.md
> Specs directory: {PLAN_DIR}/specs/

### Dependency DAG
{Copy the Mermaid graph from manifest.md here}

### Per-Spec Decisions
| Spec | Key Decision | Rationale | Affects |
|------|-------------|-----------|---------|
| {spec-name} | {decision from Gate 3} | {why} | {downstream specs} |

## Sprint Grouping
| Sprint | Specs | Can Parallelize |
|--------|-------|-----------------|
| Phase 1, Sprint 1 | {specs} | yes/no |

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

### Create progress.md

**Task-based mode** -- use without the spec sections.
**Spec-driven mode** -- include the Spec Status table.
Write to: `{PLAN_DIR}/progress.md`

```markdown
# Progress Log

## Plan: {PLAN_CATEGORY}/{PLAN_NAME}

## Session: [DATE]

<!-- SPEC-DRIVEN ONLY -->
## Spec Status
| Spec | Phase | Sprint | Status | Last Updated |
|------|-------|--------|--------|-------------|
| {spec-name} | {N} | {M} | draft | {date} |

<!-- Status values: draft > in_progress > completed | blocked | skipped -->
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

### Gate 4: Plan Validation

After creating tasks and files:

```python
# Show user the task list
TaskList()

AskUserQuestion(
  question="Created X tasks in {PLAN_CATEGORY}/{PLAN_NAME} (visible in UI). Ready to proceed?",
  header="Validate",
  options=[
    {"label": "Looks good, proceed", "description": "Start Phase 1"},
    {"label": "Adjust tasks", "description": "I want to modify the plan"},
    {"label": "Show more detail", "description": "Expand on the approach"}
  ]
)
```

### Gate 5: Architecture Review

Before writing any code, review the plan against these dimensions. For every issue or recommendation, explain the concrete tradeoffs, give an opinionated recommendation, and ask the user for input before assuming a direction.

**Evaluate:**

1. **System design & component boundaries** -- Are responsibilities cleanly separated? Are there components doing too much, or artificial splits that will cause shotgun surgery later?
2. **Dependency graph & coupling** -- Map which components depend on which. Flag circular dependencies, God-object risks, and areas where a change would cascade across boundaries.
3. **Data flow & bottlenecks** -- Trace the primary data paths. Identify where transformations happen, where data gets copied vs referenced, and any hot paths that could become bottlenecks under load.
4. **Scaling characteristics & single points of failure** -- What breaks first at 10x? At 100x? Where are the SPOFs that would take down the whole system?
5. **Security architecture** -- Review auth boundaries (who can access what, how are credentials handled). Check data access patterns (are there exposed internal models leaking through API boundaries?). Evaluate API surface area (are endpoints scoped tightly, or is there an overly permissive surface?).
6. **Error handling & failure modes** -- Distinct from SPOFs (which identify *where* failure happens). This covers *what happens after* failure. Are error paths real recovery strategies or just `catch → log → rethrow`? Does the system degrade gracefully or fall over entirely? Are failure scenarios between components handled explicitly or left to hope?
7. **Testability** -- Can components be tested in isolation? Are boundaries mockable? This is the concrete verification that dimensions 1-2 (boundaries, coupling) actually hold in practice — you can describe clean architecture on paper that's untestable due to hidden runtime dependencies. If you can't write a test for it without standing up the whole system, the design has a problem.
8. **Existing codebase fit** *(skip for greenfield)* -- Does the plan introduce a second way of doing things? If the codebase uses pattern A and the plan introduces pattern B for the same concern, that's a maintenance tax. Either commit to migrating everything to B (and scope that work) or match A for consistency.

**Format findings as:**

```markdown
#### [Dimension Name]

**Current plan:** [what the plan says]
**Concern:** [specific issue found, or "None — looks solid"]
**Tradeoff:** [what you gain vs what you lose if changed]
**Recommendation:** [opinionated direction with reasoning]
```

Then gate on the findings:

```python
AskUserQuestion(
  question="Architecture review complete — see findings above. How do you want to proceed?",
  header="Arch Review",
  options=[
    {"label": "Approve, start building", "description": "No changes needed, move to Phase 3"},
    {"label": "Revise plan", "description": "Update tasks/specs based on review findings"},
    {"label": "Dig deeper", "description": "Investigate a specific concern in more detail"}
  ]
)
```

If the user chooses **Revise plan**, update the relevant tasks, spec files, and findings.md, then re-run Gate 5. If **Dig deeper**, investigate and present findings before asking again.

**Engineering calibration:** Throughout the review, target code that's "engineered enough" — not under-engineered (fragile, hacky, missing obvious error paths) and not over-engineered (premature abstractions, speculative generality, unnecessary indirection). When flagging a concern, explicitly state which side it leans toward and what the right level of investment looks like for this specific project's stage and scale.

---

## Phase 3: Execution with Checkpoints

### Task Status Updates

```python
TaskUpdate(taskId="1", status="in_progress")   # when starting
TaskUpdate(taskId="1", status="completed")      # when done (auto-unblocks next task)
```

### Manual Checkpoints (use AskUserQuestion)

| Trigger | Action |
|---------|--------|
| Phase complete | TaskUpdate(completed) + "Phase N done. Continue?" |
| Unexpected complexity | "More complex than expected. Simplify scope, extend timeline, or proceed?" |
| 3-strike error | "Hit 3 failures. Try alternative, ask for help, or skip?" |
| Scope creep | TaskCreate for new work + "New scope detected. Add task or defer?" |

### The 2-Action Rule

After every 2 view/browser/search operations, write findings to `{PLAN_DIR}/findings.md` immediately. Multimodal content doesn't persist -- capture as text now.

### The 3-Strike Protocol

```
ATTEMPT 1: Diagnose & fix
ATTEMPT 2: Alternative approach (never repeat same action)
ATTEMPT 3: Broader rethink, search for solutions
AFTER 3:   AskUserQuestion to escalate
```

---

## Critical Rules

1. **Gates before tasks** - Run interactive gates before creating tasks
2. **Tasks before code** - TaskCreate for all phases before any implementation
3. **Review before code** - Run Gate 5 (Architecture Review) after plan validation, before any implementation
4. **Update task status** - TaskUpdate(in_progress) when starting, (completed) when done
5. **Read findings before decide** - Re-read `{PLAN_DIR}/findings.md` for big decisions
6. **Log to files** - Errors/research go in `{PLAN_DIR}/progress.md` and `{PLAN_DIR}/findings.md`
7. **Ask when stuck** - Use AskUserQuestion at checkpoints, not just initially

---

## When to Use

**Use for:** Multi-step tasks, unclear requirements, multiple valid approaches, research, anything needing user alignment.

**Skip for:** Simple questions, single-file edits, tasks with obvious solutions.

---

## Anti-Patterns

| Don't | Do Instead |
|-------|------------|
| Create tasks without asking scope | Run Gate 1 first |
| Assume requirements | Validate with Gate 2 |
| Pick approach silently | Use Gate 3 if multiple options |
| Start coding without tasks | TaskCreate for all phases FIRST |
| Skip architecture review | Run Gate 5 before any implementation |
| Assume an architecture direction silently | Present tradeoffs, recommend, ask for input |
| Track progress in markdown checkboxes | Use TaskUpdate for status |
| Store large research in task descriptions | Use `{PLAN_DIR}/findings.md` |
| Ask too many questions | Batch related questions |
| Forget to update task status | TaskUpdate(completed) when done |
| Use hardcoded docs/plans/ paths | Always use `{PLAN_DIR}` variable |

---
name: interactive-planning
version: "4.1.0"
description: "File-based planning with interactive gates and native task tracking. Use when user says /plan, needs to break a complex feature into phases, or wants structured implementation planning with user approval at key decision points. Supports task mode (single plan file) and spec mode (multi-file architecture)."
user-invocable: true
allowed-tools: ["Read","Write","Edit","Bash","Glob","Grep","WebFetch","WebSearch","AskUserQuestion","TaskCreate","TaskUpdate","TaskList","TaskGet"]
hooks:
  PreToolUse:
    - matcher: "Write|Edit|Bash|Read|Glob|Grep"
      hooks:
        - type: command
          command: "cat findings.md 2>/dev/null | head -30 || true"
  PostToolUse:
    - matcher: "Write|Edit"
      hooks:
        - type: command
          command: "echo '[interactive-planning] File updated. If this completes a phase, use TaskUpdate to mark completed.'"
---

# Interactive Planning (Manus + AskUserQuestion)

Combines **file-based persistence** (Manus-style) with **interactive clarification gates**.

## Core Philosophy

```
Context Window = RAM (volatile, limited)
Filesystem = Disk (persistent, unlimited)
Task Tools = Structured progress (visible, stateful)
AskUserQuestion = User alignment (prevents rework)

→ Tasks for actions (TaskCreate/Update)
→ Files for knowledge (findings.md)
→ Ask users before committing to approaches
```

---

## Phase 0: Session Recovery

**Before anything else**, check for unsynced context:

```bash
python3 ~/.claude/skills/planning-with-files/scripts/session-catchup.py "$(pwd)"
```

If catchup shows unsynced context:
1. `git diff --stat` to see code changes
2. Read existing planning files
3. Update files based on context
4. Then proceed

---

## Phase 1: Interactive Requirements Gathering

### Gate 1: Planning Mode + Priority

Use AskUserQuestion BEFORE creating any files. Two questions:

**Question 1: Planning Mode**
```python
AskUserQuestion(
  question="What kind of planning does this need?",
  header="Mode",
  options=[
    {"label": "Task-based (Recommended)", "description": "Single task_plan.md with phases. Best for straightforward features."},
    {"label": "Spec-driven", "description": "Multiple spec files per concern, manifest index. Best for complex multi-domain work."}
  ]
)
```

If "Task-based" → continue with existing flow (Gates 2-4 unchanged).
If "Spec-driven" → continue with Gates 2, 3 (enhanced), 4 (enhanced) below.

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

### Gate 3: Approach Decision (if multiple valid approaches)

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

If spec-driven mode was selected in Gate 1, replace Gate 3 above with this combined gate.

The agent:
1. Analyzes requirements from Gate 2
2. Proposes an architectural approach
3. Decomposes into spec files with dependency relationships
4. Auto-computes sprint/phase grouping via topological sort of dependency DAG
5. Presents everything together for user validation

Present to user:

```
Based on your requirements, here's the approach and spec breakdown:

**Approach:** {description of chosen approach with rationale}

**Spec Decomposition:**
- root-spec.md — {description} (parent of all)
  ├── {name}-spec.md — {description}
  ├── {name}-spec.md — {description} (depends on: {dep})
  └── {name}-spec.md — {description} (depends on: {dep})

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
    {"label": "Too granular", "description": "Merge some specs together — fewer, larger specs"},
    {"label": "Not granular enough", "description": "Split some specs further"}
  ]
)
```

**Sprint/Phase auto-assignment algorithm:**
1. Topological sort of spec dependency DAG
2. Specs with no unmet dependencies → same sprint
3. Specs whose deps are all in earlier sprints → next sprint
4. Sprint groups → phases (one phase per dependency "level")
5. User can override at Gate 4

---

## Phase 2: Create Tasks and Files

After gates pass, create **tasks** for phases and **files** for research:

### Phase 2 (Spec-Driven): Create Manifest + Spec Files

If spec-driven mode was selected in Gate 1, replace the task_plan.md creation below with this path.

#### Step 1: Create specs/ directory

```bash
mkdir -p docs/plans/specs
```

#### Step 2: Generate manifest.md

Use template from `~/.claude/skills/orchestrator/templates/manifest-template.md`.
Fill in:
- Project name, date, mode ("spec-driven"), priority from Gate 1
- Dependency graph (Mermaid) from Gate 3 decomposition
- Phase/Sprint/Spec map from auto-assignment
- Spec files table with paths and approximate line counts

Write to: `docs/plans/manifest.md`

#### Step 3: Generate individual spec files

For each spec identified in Gate 3, use template from
`~/.claude/skills/orchestrator/templates/spec-template.md`.
Fill in:
- YAML frontmatter: name, phase, sprint, parent, depends_on, status=draft, created date
- Requirements: distribute Gate 2 requirements to relevant specs
- Acceptance criteria: derive testable criteria from requirements
- Technical approach: from Gate 3
- Files: infer from CODEBASE_MAP or project structure
- Tasks: derive 2-5 tasks per spec from requirements
- Dependencies: what it needs from upstream specs, what it provides downstream

Write each to: `docs/plans/specs/{name}-spec.md`

#### Step 4: Create findings.md (spec-driven enhanced)

Use the **spec-driven findings.md template** below (not the task-based version).
The extra sections give `/orchestrate` the dependency graph and per-spec decision
traceability it needs for skill-matching and agent dispatch.

#### Step 5: Create progress.md (spec-driven enhanced)

Use the **spec-driven progress.md template** below (not the task-based version).
The Spec Status table is the primary resume signal for `/orchestrate --resume`.

#### Step 6: Create two-level TaskCreate entries

Create tasks at two levels: **spec tasks** (parents) and **sub-tasks** (from the spec's ## Tasks section).
This gives `/orchestrate` granular dispatch — it can assign individual sub-tasks to agents
and track completion within each spec.

**Level 1 — Spec tasks (inter-spec blocking via DAG):**

```python
# Create one parent task per spec
TaskCreate(
  subject="Spec: {spec-name}",
  description="Implement docs/plans/specs/{spec-name}-spec.md\nPhase {N}, Sprint {M}\nDepends on: {deps}\n\nThis is a parent task. Sub-tasks below do the actual work.",
  activeForm="Implementing {spec-name}"
)
# Returns task ID, e.g. "1"

# Wire inter-spec dependencies from the DAG
# If api-spec depends on data-model-spec:
TaskUpdate(taskId="{api-spec-task}", addBlockedBy=["{data-model-spec-task}"])
```

**Level 2 — Sub-tasks (intra-spec blocking, sequential within each spec):**

For each task listed in the spec's `## Tasks` section, create a sub-task
that references its parent spec and is blocked by the previous sub-task:

```python
# Spec: data-model has 3 tasks in its ## Tasks section:

# Sub-task 1 — blocked by the parent spec's upstream dependencies (inherits)
TaskCreate(
  subject="data-model: Create database schema",
  description="Spec: data-model (Phase 1, Sprint 1)\nParent task: #{spec_task_id}\nFile targets: {from spec ## Files table}",
  activeForm="Creating database schema"
)
# Returns e.g. "1a"
TaskUpdate(taskId="1a", addBlockedBy=["{upstream_spec_last_subtask or spec_blockers}"])

# Sub-task 2 — blocked by sub-task 1
TaskCreate(
  subject="data-model: Write migration",
  description="Spec: data-model (Phase 1, Sprint 1)\nParent task: #{spec_task_id}",
  activeForm="Writing migration"
)
# Returns e.g. "1b"
TaskUpdate(taskId="1b", addBlockedBy=["1a"])

# Sub-task 3 — blocked by sub-task 2
TaskCreate(
  subject="data-model: Add seed data",
  description="Spec: data-model (Phase 1, Sprint 1)\nParent task: #{spec_task_id}",
  activeForm="Adding seed data"
)
# Returns e.g. "1c"
TaskUpdate(taskId="1c", addBlockedBy=["1b"])
```

**Inter-spec handoff rule:** A downstream spec's first sub-task is blocked by the
upstream spec's **last** sub-task (not the parent). This prevents the downstream
spec from starting before the upstream spec's work is actually finished:

```python
# api-spec depends on data-model. data-model's last sub-task is "1c".
# api-spec's first sub-task:
TaskCreate(subject="api-layer: Define route handlers", ...)
TaskUpdate(taskId="{api_first_subtask}", addBlockedBy=["1c"])
# NOT addBlockedBy: ["1"] — the parent task is a grouping label, not a gate.
```

**Naming convention:** Sub-task subjects are prefixed with their spec name
(`data-model: Create schema`) so the flat task list stays readable.

**Completion rule:** When ALL sub-tasks for a spec are completed,
mark the parent spec task as completed too:
```python
# After all data-model sub-tasks done:
TaskUpdate(taskId="{data-model-spec-task}", status="completed")
```

Then continue to Gate 4 below (which validates the full structure).

### Create Tasks with TaskCreate (Task-Based Mode)

For each phase identified, create a task:

```python
# Phase 1
TaskCreate(
  subject="Phase 1: [Title]",
  description="[Details from gates]\n- Task 1\n- Task 2",
  activeForm="Working on Phase 1"
)

# Phase 2 (blocked by Phase 1)
TaskCreate(
  subject="Phase 2: [Title]",
  description="[Details]",
  activeForm="Working on Phase 2"
)
# Then: TaskUpdate(taskId="2", addBlockedBy=["1"])
```

### Create findings.md and progress.md

Consult `references/templates.md` for the full findings.md and progress.md templates. Both have task-based and spec-driven variants.

### Gate 4: Plan Validation

After creating tasks and files:

```python
# First show user the task list
TaskList()

AskUserQuestion(
  question="Created X tasks (visible in UI). Ready to proceed?",
  header="Validate",
  options=[
    {"label": "Looks good, proceed", "description": "Start Phase 1"},
    {"label": "Adjust tasks", "description": "I want to modify the plan"},
    {"label": "Show more detail", "description": "Expand on the approach"}
  ]
)
```

---

## Phase 3: Execution with Checkpoints

### Task Status Updates

**When starting a phase:**
```python
TaskUpdate(taskId="1", status="in_progress")
```

**When completing a phase:**
```python
TaskUpdate(taskId="1", status="completed")
# Next task auto-unblocks if it was waiting
```

### Automatic Behaviors (via hooks)

- **PreToolUse**: Auto-reads findings.md before Write/Edit/Bash
- **PostToolUse**: Reminds to update task status after file changes

### Manual Checkpoints (use AskUserQuestion)

| Trigger | Action |
|---------|--------|
| Phase complete | TaskUpdate(completed) + "Phase N done. Continue?" |
| Unexpected complexity | "More complex than expected. Simplify scope, extend timeline, or proceed?" |
| 3-strike error | "Hit 3 failures. Try alternative, ask for help, or skip?" |
| Scope creep | TaskCreate for new work + "New scope detected. Add task or defer?" |

### The 2-Action Rule

After every 2 view/browser/search operations:
→ IMMEDIATELY write findings to findings.md
→ Multimodal content doesn't persist - capture as text NOW

### The 3-Strike Protocol

```
ATTEMPT 1: Diagnose & fix
ATTEMPT 2: Alternative approach (NEVER repeat same action)
ATTEMPT 3: Broader rethink, search for solutions
AFTER 3: AskUserQuestion to escalate
```

---

## Critical Rules

1. **Gates before tasks** - Run interactive gates before creating tasks
2. **Tasks before code** - TaskCreate for all phases before any implementation
3. **Update task status** - TaskUpdate(in_progress) when starting, (completed) when done
4. **Read findings before decide** - Re-read findings.md for big decisions
5. **Log to files** - Errors/research go in progress.md and findings.md
6. **Ask when stuck** - Use AskUserQuestion at checkpoints, not just initially

---

## When to Use

Consult `references/templates.md` for full template files and detailed "when to use / skip" guidance.

---

## Anti-Patterns

| Don't | Do Instead |
|-------|------------|
| Create tasks without asking scope | Run Gate 1 first |
| Assume requirements | Validate with Gate 2 |
| Pick approach silently | Use Gate 3 if multiple options |
| Start coding without tasks | TaskCreate for all phases FIRST |
| Track progress in markdown checkboxes | Use TaskUpdate for status |
| Store large research in task descriptions | Use findings.md |
| Ask too many questions | Batch related questions |
| Forget to update task status | TaskUpdate(completed) when done |

---

## Phase 4: Worktree Orchestration (Optional)

For plans with 2+ phases, offer parallel worktree execution. Full protocol in `references/worktree-orchestration.md` — covers Gate 5 setup decision, worktree creation, mother/worker agent spawning, and merge flow.

## Handoff to /orchestrate

After Gate 4, if the user wants automated execution, hand off to the `/orchestrate` skill which reads findings.md and progress.md to drive the 6-stage pipeline (plan ingestion → review → skill matching → agent dispatch → testing → code review). The orchestrator consumes the same file artifacts this skill produces.
| All phases done | Mother reports final summary |

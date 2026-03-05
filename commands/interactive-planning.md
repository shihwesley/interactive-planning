---
name: interactive-planning
version: "4.1.0"
description: "File-based planning with interactive gates + native task tracking. Supports task-based (single plan file) and spec-driven (multi-file specs with manifest) modes. Phase/Sprint/Spec hierarchy with dependency DAG."
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

## Phase 0.5: Research Discovery

**After session recovery, before any planning gates**, check if the user has already researched the topic via `/research`.

### Step 1: Scan for existing research

```bash
# Resolve home dir (Read/Glob don't expand ~)
HOME_DIR=$(echo ~)
ls "$HOME_DIR/.claude/research/" 2>/dev/null
```

If research topics exist, compare against the user's planning request. Match by keyword overlap — e.g., if planning "visionOS app" and `visionos-development/` exists, that's a match.

### Step 2: Load matching research

For each matching research topic:

```bash
# Check what artifacts exist
ls "$HOME_DIR/.claude/research/<slug>/"
# Read sources.json for artifact paths
```

From `sources.json`, extract:
- `expertise` path → read expertise.md (3-5K tokens, compact overview)
- `skill` path → note for skill loading during implementation
- `subagent` path → note for specialist agent dispatch during orchestration
- `knowledge_store` path → note the .mv2 location for `rlm_search` queries

### Step 3: Make research available during planning

If research artifacts were found:

1. **Pre-load expertise** into your working context — read the expertise.md file. This gives you domain knowledge for better requirements gathering and approach selection.

2. **Enable knowledge store deep-dives** — during any subsequent gate, you can query the research store:
   ```
   ToolSearch(query="rlm_search")
   rlm_search(query="<specific technical question>", project="<slug>")
   ```
   Use this when a gate requires technical detail the expertise doc doesn't cover.

3. **Record in findings.md** (created in Phase 2):
   ```markdown
   ## Research Context
   | Topic | Expertise | Knowledge Store | Skill | Agent |
   |-------|-----------|----------------|-------|-------|
   | <slug> | ~/.claude/research/<slug>/expertise.md | <.mv2 path> | <skill path or —> | <agent path or —> |

   Deep-dive: rlm_search(query="...", project="<slug>")
   ```

### Step 4: Suggest missing research

If no matching research exists and the topic is technically complex:

```python
AskUserQuestion(
  question="No existing research found for this topic. Research first?",
  header="Research",
  options=[
    {"label": "Research first (Recommended)", "description": "Run /research <topic> to build a knowledge base before planning"},
    {"label": "Skip research", "description": "Plan without a knowledge base — rely on training data"},
    {"label": "I have docs to index", "description": "I'll provide URLs or local docs to index"}
  ]
)
```

If "Research first" → tell user to run `/research <topic>` and come back.
If "I have docs to index" → use `rlm_fetch(url)` or `rlm_load_dir(glob)` to index user-provided docs before proceeding.
If "Skip research" → continue with standard planning flow.

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

**Question 3: Project Type**
```python
AskUserQuestion(
  question="What type of project is this?",
  header="Project Type",
  options=[
    {"label": "Greenfield", "description": "Building from scratch — idea to prototype to production"},
    {"label": "Brownfield", "description": "Adding features or fixing bugs in existing codebase"},
    {"label": "Prototype", "description": "Quick proof of concept, not production-grade yet"}
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

### Gate 2.5: Skill Graph Discovery

**Before choosing an approach**, consult skill graphs to understand what domain knowledge is available.

1. Read `.claude/skills/orchestrator/skill-registry.json`
2. Extract keywords from the user's request and Gate 2 requirements
3. Check the `graphPaths` map — if any keyword matches, read the skill graph index
4. From the index, identify relevant MOCs and scan them for applicable skills/plugins
5. Record discovered skills in findings.md under a `## Available Skills` section

**Available skill graphs:**
- Swift/iOS/visionOS: `.claude/docs/swift-graph/index.md` — 13 MOCs covering architecture, SwiftUI, spatial computing, concurrency, persistence, AI/ML, testing, HIG design, logging, App Store, distribution, tooling

This step ensures Gate 3 presents approaches informed by what skills and plugins exist. For example, if the task involves visionOS + accessibility, the graph reveals both `visionos-specialist` agents and `apple-hig-skills` HIG plugins — which shapes the approach options.

### Gate 3: Approach Decision (if multiple valid approaches)

**Research-informed approach selection:** If Phase 0.5 loaded research artifacts, use them here. If Gate 2.5 found relevant skills, factor them into approach feasibility. Before presenting options, query the knowledge store for relevant patterns, tradeoffs, or prior art:

```
# Example: deciding between two database approaches
rlm_search(query="recommended architecture patterns", project="<slug>")
rlm_search(query="performance tradeoffs", project="<slug>")
```

Include findings from the knowledge store in the approach descriptions — this grounds options in researched facts rather than training-data assumptions.

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

Read the template (resolve `~` to absolute path first — Read/Glob do NOT expand tilde):
`$HOME/.claude/skills/orchestrator/templates/manifest-template.md`
Fill in:
- Project name, date, mode ("spec-driven"), priority from Gate 1
- Dependency graph (Mermaid) from Gate 3 decomposition
- Phase/Sprint/Spec map from auto-assignment
- Spec files table with paths and approximate line counts

Write to: `docs/plans/manifest.md`

#### Step 3: Generate individual spec files

For each spec identified in Gate 3, read the template (resolve `~` first):
`$HOME/.claude/skills/orchestrator/templates/spec-template.md`.
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

### Create findings.md

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

## Research Context
<!-- Populated from Phase 0.5 research discovery -->
| Topic | Expertise | Knowledge Store | Skill | Agent |
|-------|-----------|----------------|-------|-------|
<!-- Fill from ~/.claude/research/<slug>/sources.json artifacts field -->

Deep-dive queries:
- `rlm_search(query="...", project="<slug>")`
- `rlm_ask(question="...", project="<slug>")`

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

### Create workflow.md (execution contract)

After creating findings.md and progress.md, generate the execution contract that bridges planning and orchestration.

Read the workflow template (resolve ~ first):
`$HOME/.claude/skills/orchestrator/templates/workflow-template.md`

Fill in from gate decisions:
- `project.name`: from git repo name or user specification
- `project.type`: from Gate 1 Question 3 (greenfield/brownfield/prototype)
- `project.build_cmd`: from project CLAUDE.md Build Commands section, or ask user
- `project.test_cmd`: from project CLAUDE.md Build Commands section, or ask user
- `execution.gates.between_phases`: derive from Gate 1 priority:
  - Speed → `auto`
  - Quality → `review`
  - Flexibility → `manual`
  - Simplicity → `auto`
- Phase/Continuation prompt templates: use defaults from template (user can customize later)

Write to: `{plan_dir}/workflow.md`

### Create handoff.md (inter-agent communication)

Read the handoff template:
`$HOME/.claude/skills/orchestrator/templates/handoff-template.md`

Fill in:
- `project.name`, `project.type`, `project.build_cmd`, `project.test_cmd`: same as workflow.md
- `current_phase`: first phase from the plan (name, number, criteria)

Write to: `{git_root}/.claude/handoff.md`

Create the `.claude/` directory if it doesn't exist:
```bash
mkdir -p "$(git rev-parse --show-toplevel)/.claude"
```

### Create progress-log.md (append-only history)

Read the progress-log template:
`$HOME/.claude/skills/orchestrator/templates/progress-log-template.md`

Fill in:
- `project.name`: same as above
- `date`: current date
- `workflow_path`: relative path to workflow.md from git root
- `plan_path`: relative path to plan directory from git root

Write to: `{git_root}/.claude/progress-log.md`

### Gate 4: Plan Validation

After creating tasks and files:

```python
# First show user the task list
TaskList()

AskUserQuestion(
  question="Created X tasks + workflow contract (workflow.md, handoff.md, progress-log.md). Ready to proceed?",
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

## Templates

Located at `$HOME/.claude/skills/planning-with-files/templates/` (resolve `$HOME` before passing to Read):
- `task_plan.md`
- `findings.md`
- `progress.md`

---

## When to Use

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

After Gate 4 validation, if the plan has **2+ phases**, offer to set up parallel worktrees:

### Gate 5: Worktree Setup Decision

```python
AskUserQuestion(
  question="Plan has N phases. Set up worktrees for parallel work?",
  header="Worktrees",
  options=[
    {"label": "Yes, create worktrees (Recommended)", "description": "One worktree per phase, mother agent orchestrates"},
    {"label": "No, work in current branch", "description": "Sequential work in single workspace"},
    {"label": "Partial", "description": "Create worktrees only for independent phases"}
  ]
)
```

### Worktree Creation Flow

If user selects "Yes" or "Partial":

```bash
# 1. Verify in git repo
git rev-parse --git-dir

# 2. Check/create worktree directory (per using-git-worktrees skill)
ls -d .worktrees 2>/dev/null || mkdir -p .worktrees
git check-ignore -q .worktrees || echo ".worktrees/" >> .gitignore

# 3. Create worktree per phase
# Pattern: .worktrees/<project>-phase-<N>-<slug>
git worktree add .worktrees/phase-1-<slug> -b feature/phase-1-<slug>
git worktree add .worktrees/phase-2-<slug> -b feature/phase-2-<slug>
# ... for each phase

# 4. List created worktrees
git worktree list
```

### Update findings.md with Worktree Map

```markdown
## Worktree Map
| Phase | Branch | Worktree Path | Status |
|-------|--------|---------------|--------|
| 1 | feature/phase-1-<slug> | .worktrees/phase-1-<slug> | ready |
| 2 | feature/phase-2-<slug> | .worktrees/phase-2-<slug> | ready |
```

### Mother Agent Spawn

After worktrees created, spawn orchestrating agent:

```python
Task(
  subagent_type="general-purpose",
  model="opus",
  prompt="""
  You are the MOTHER AGENT orchestrating multi-phase work.

  ## Your Worktrees
  [Insert worktree map from findings.md]

  ## Your Tasks (from TaskList)
  [Insert task IDs and descriptions]

  ## Your Job
  1. For each phase, spawn a worker agent using Task tool:
     - subagent_type: "general-purpose" (or appropriate specialist)
     - prompt: Include worktree path, task details, acceptance criteria
     - run_in_background: true (for parallel independent phases)

  2. Track progress via TaskList/TaskUpdate

  3. When phase completes:
     - Mark task completed
     - Merge worktree to main (or create PR)
     - Clean up worktree: git worktree remove <path>

  4. Coordinate dependencies:
     - Phases with blockedBy cannot start until dependency completes
     - Independent phases can run in parallel

  ## findings.md Location
  $(pwd)/findings.md - Update with discoveries

  ## Completion Criteria
  All tasks completed, worktrees merged/cleaned, final summary written.
  """
)
```

### Worker Agent Prompt Template

For each phase, mother agent spawns:

```python
Task(
  subagent_type="general-purpose",  # or swift-engineering:*, visionos-specialist, etc.
  model="sonnet",
  run_in_background=True,  # if independent
  prompt="""
  ## Your Workspace
  cd {worktree_path}

  ## Your Task
  {task_description from TaskGet}

  ## Skill Graph
  Before starting, read the skill graph index for your domain:
  - Swift/iOS/visionOS: .claude/docs/swift-graph/index.md
  Navigate to the MOC matching your task, then load the specific skills listed there.
  This tells you which plugins and skills are available (e.g., swiftui-expert, swift-concurrency,
  apple-hig-skills, swift-logging, core-data-expert, swift-testing-expert).

  ## Skills to Load
  {skills discovered in Gate 2.5 / skill-matcher — list specific skill names here}

  ## Acceptance Criteria
  {from findings.md}

  ## Rules
  1. Work ONLY in your worktree
  2. Commit frequently with clear messages
  3. Run tests before marking done
  4. Update findings.md with discoveries
  5. When done: TaskUpdate(taskId="{task_id}", status="completed")

  ## DO NOT
  - Touch other worktrees
  - Merge branches (mother agent handles)
  - Create new phases (ask mother agent)
  """
)
```

---

## Quick Reference: Worktree Orchestration

| Condition | Action |
|-----------|--------|
| 1 phase | Skip worktrees, work directly |
| 2+ phases | Offer Gate 5 |
| User selects "Yes" | Create all worktrees + spawn mother |
| User selects "Partial" | Ask which phases, create those worktrees |
| Phases have dependencies | Worker waits for blockedBy to complete |
| Phases independent | Workers run in parallel (run_in_background) |
| Phase complete | Mother merges/PRs, cleans worktree |
| All phases done | Mother reports final summary |

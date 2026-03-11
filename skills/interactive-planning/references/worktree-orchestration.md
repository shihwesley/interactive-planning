# Phase 4: Worktree Orchestration (Optional)

After Gate 4 validation, if the plan has **2+ phases**, offer to set up parallel worktrees:

## Gate 5: Worktree Setup Decision

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

## Worktree Creation Flow

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

## Update findings.md with Worktree Map

```markdown
## Worktree Map
| Phase | Branch | Worktree Path | Status |
|-------|--------|---------------|--------|
| 1 | feature/phase-1-<slug> | .worktrees/phase-1-<slug> | ready |
| 2 | feature/phase-2-<slug> | .worktrees/phase-2-<slug> | ready |
```

## Mother Agent Spawn

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

## Worker Agent Prompt Template

For each phase, mother agent spawns:

```python
Task(
  subagent_type="general-purpose",  # or swift-engineering:*, feature-dev:*, etc.
  model="sonnet",
  run_in_background=True,  # if independent
  prompt="""
  ## Your Workspace
  cd {worktree_path}

  ## Your Task
  {task_description from TaskGet}

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

## Quick Reference

| Condition | Action |
|-----------|--------|
| 1 phase | Skip worktrees, work directly |
| 2+ phases | Offer Gate 5 |
| User selects "Yes" | Create all worktrees + spawn mother |
| User selects "Partial" | Ask which phases, create those worktrees |
| Phases have dependencies | Worker waits for blockedBy to complete |
| Phases independent | Workers run in parallel (run_in_background) |
| Phase complete | Mother merges/PRs, cleans worktree |

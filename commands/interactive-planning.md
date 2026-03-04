---
description: Manage interactive planning sessions (start, status, resume, reset)
argument-hint: [status|resume [category/name]|reset [category/name]]
allowed-tools: ["Read", "Write", "Edit", "Bash", "AskUserQuestion", "TaskCreate", "TaskUpdate", "TaskList", "TaskGet", "Skill"]
---

# Interactive Planning Command

**Arguments received:** $ARGUMENTS

## Route by argument

Parse `$ARGUMENTS` and route to the correct action:

### No arguments (or "start" or "new")
Start a new planning session. Invoke the `interactive-planning` skill using the Skill tool:
```
Skill(skill="interactive-planning")
```
Then follow the skill instructions (Phase 0.5 auto-detection through Gate 5).

### "status" or "status {category/name}"
Show current planning session status.

1. Scan for all plans:
   ```bash
   find docs/plans -mindepth 3 -maxdepth 3 \( -name manifest.md -o -name task_plan.md \) 2>/dev/null
   ls task_plan.md findings.md progress.md docs/plans/manifest.md 2>/dev/null
   ```

2. If **no plans found**: Report "No active planning session. Run `/interactive-planning` to start one."

3. If **specific plan requested** (e.g., `status feat/auth`):
   - Set `PLAN_DIR = docs/plans/{category}/{name}`
   - Read `{PLAN_DIR}/findings.md` for goal, priority, approach
   - Read `{PLAN_DIR}/manifest.md` or `{PLAN_DIR}/task_plan.md` for plan details
   - Read `{PLAN_DIR}/progress.md` for the 5-Question Reboot Check
   - Run `TaskList()` to show task progress
   - Present a summary: category, name, mode, current phase, completed/total tasks

4. If **no specific plan** and **multiple plans exist**:
   - List all plans with their category, name, mode, and high-level status
   - Format as a table:
     ```
     | Plan | Mode | Status | Tasks |
     |------|------|--------|-------|
     | feat/auth-system | spec-driven | Phase 1, Sprint 2 | 3/7 done |
     | fix/login-crash | task-based | Phase 2 | 4/6 done |
     ```
   - Ask which plan to inspect for details

5. If **single plan exists** (categorized or legacy):
   - Show full status for that plan (same as specific plan request)

### "resume" or "resume {category/name}"
Resume an existing planning session.

1. Scan for all plans (same as status)

2. If **no plans found**: "Nothing to resume. Run `/interactive-planning` to start a new session."

3. If **specific plan requested** (e.g., `resume feat/auth`):
   - Set `PLAN_DIR = docs/plans/{category}/{name}`
   - Read all planning files from `{PLAN_DIR}/`
   - Run `TaskList()` to find the next unblocked, pending task
   - `git diff --stat` to see what changed since last session
   - Report what happened and what's next
   - Ask: "Ready to continue from [current phase/task]?"

4. If **no specific plan** and **multiple plans exist**:
   ```python
   AskUserQuestion(
     question="Which plan do you want to resume?",
     header="Resume",
     options=[
       # One option per discovered plan, e.g.:
       {"label": "feat/auth-system", "description": "Spec-driven, Phase 1 Sprint 2"},
       {"label": "fix/login-crash", "description": "Task-based, Phase 2"}
     ]
   )
   ```
   Then resume the selected plan.

5. If **single plan exists**: Resume it directly (same as specific plan request).

6. If **legacy flat-path plan found** (task_plan.md at root or docs/plans/manifest.md without category):
   - Resume from legacy paths — read task_plan.md/manifest.md, findings.md, progress.md from their original locations
   - Do not attempt to migrate mid-session

### "reset" or "reset {category/name}"
Clean up planning files from the current project.

1. Scan for all plans

2. If **no plans found**: "No planning files to clean up."

3. If **specific plan requested** (e.g., `reset feat/auth`):
   ```python
   AskUserQuestion(
     question="This will remove the feat/auth plan directory and all its files. Are you sure?",
     header="Reset",
     options=[
       {"label": "Yes, remove plan", "description": "Delete docs/plans/feat/auth/ entirely"},
       {"label": "Keep findings", "description": "Remove plan files but keep findings.md"},
       {"label": "Cancel", "description": "Don't remove anything"}
     ]
   )
   ```

4. If **no specific plan** and **multiple plans exist**:
   ```python
   AskUserQuestion(
     question="Which plans do you want to reset?",
     header="Reset",
     multiSelect=True,
     options=[
       # One option per discovered plan plus "all":
       {"label": "feat/auth-system", "description": "Spec-driven, 3 specs"},
       {"label": "fix/login-crash", "description": "Task-based"},
       {"label": "All plans", "description": "Remove entire docs/plans/ directory"}
     ]
   )
   ```

5. If **single plan exists**: Show confirmation for that plan.

6. Remove the selected plan directory (or just the non-findings files if "Keep findings" selected).

7. Note: This does NOT clear TaskList tasks. Mention this to the user.

### "list"
List all planning sessions with a summary table.

1. Scan for all categorized plans + legacy plans
2. Display as table:
   ```
   | # | Plan | Mode | Category | Status |
   |---|------|------|----------|--------|
   | 1 | feat/auth-system | spec-driven | feat | Phase 1, Sprint 2 |
   | 2 | fix/login-crash | task-based | fix | Phase 2 |
   | 3 | (legacy) | task-based | — | Phase 1 |
   ```
3. Suggest: "Use `/interactive-planning resume {category/name}` to resume a specific plan."

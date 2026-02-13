---
description: Manage interactive planning sessions (start, status, resume, reset)
argument-hint: [status|resume|reset]
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
Then follow the skill instructions (Gate 1 through Gate 4).

### "status"
Show current planning session status.

1. Check for planning files:
   ```bash
   ls task_plan.md findings.md progress.md docs/plans/manifest.md 2>/dev/null
   ```

2. If **no files found**: Report "No active planning session. Run `/interactive-planning` to start one."

3. If **task_plan.md or findings.md exist** (task-based mode):
   - Read findings.md for goal, priority, approach
   - Run `TaskList()` to show task progress
   - Read progress.md for the 5-Question Reboot Check
   - Present a summary: current phase, completed/total tasks, last action

4. If **docs/plans/manifest.md exists** (spec-driven mode):
   - Read manifest.md for the Phase/Sprint/Spec map
   - Run `TaskList()` for task-level progress
   - Read progress.md for the Spec Status table
   - Present: current phase/sprint, specs completed vs total, blocked specs

### "resume"
Resume an existing planning session.

1. Check for planning files (same as status)
2. If no files: "Nothing to resume. Run `/interactive-planning` to start a new session."
3. If files exist:
   - Read all planning files
   - Run `TaskList()` to find the next unblocked, pending task
   - Read findings.md for context
   - `git diff --stat` to see what changed since last session
   - Report what happened and what's next
   - Ask: "Ready to continue from [current phase/task]?"

### "reset"
Clean up planning files from the current project.

1. Check for planning files
2. If no files: "No planning files to clean up."
3. If files exist, show what will be removed:
   ```
   AskUserQuestion(
     question="This will remove all planning files. Are you sure?",
     header="Reset",
     options=[
       {"label": "Yes, remove all", "description": "Delete task_plan.md, findings.md, progress.md, and docs/plans/"},
       {"label": "Keep findings", "description": "Remove task_plan.md and progress.md but keep findings.md"},
       {"label": "Cancel", "description": "Don't remove anything"}
     ]
   )
   ```
4. Remove the selected files
5. Note: This does NOT clear TaskList tasks. Mention this to the user.

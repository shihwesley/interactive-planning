#!/bin/bash
# SessionStart hook: detect existing planning files in the project
# Outputs a systemMessage if planning files are found

set -euo pipefail

cwd="${CLAUDE_PROJECT_DIR:-.}"

found_files=()
mode="none"

# Check task-based mode files
[ -f "$cwd/task_plan.md" ] && found_files+=("task_plan.md")
[ -f "$cwd/findings.md" ] && found_files+=("findings.md")
[ -f "$cwd/progress.md" ] && found_files+=("progress.md")

# Check spec-driven mode files
if [ -f "$cwd/docs/plans/manifest.md" ]; then
  found_files+=("docs/plans/manifest.md")
  mode="spec-driven"
  # Count spec files
  spec_count=$(ls "$cwd/docs/plans/specs/"*-spec.md 2>/dev/null | wc -l | tr -d ' ')
  if [ "$spec_count" -gt 0 ]; then
    found_files+=("$spec_count spec files")
  fi
elif [ ${#found_files[@]} -gt 0 ]; then
  mode="task-based"
fi

if [ ${#found_files[@]} -eq 0 ]; then
  # No planning files, exit silently
  exit 0
fi

# Extract current phase from progress.md if it exists
current_phase=""
if [ -f "$cwd/progress.md" ]; then
  current_phase=$(grep -m1 "Status.*in_progress" "$cwd/progress.md" 2>/dev/null | head -1 || true)
fi

# Build the message
file_list=$(IFS=', '; echo "${found_files[*]}")
msg="[interactive-planning] Existing planning session detected ($mode mode). Files: $file_list."
if [ -n "$current_phase" ]; then
  msg="$msg Currently in progress: $current_phase."
fi
msg="$msg Use '/interactive-planning resume' to continue or '/interactive-planning status' for details."

echo "$msg"

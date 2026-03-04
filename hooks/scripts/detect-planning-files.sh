#!/bin/bash
# SessionStart hook: detect existing planning files in the project
# Supports both categorized (v5+) and legacy flat-path plans

set -euo pipefail

cwd="${CLAUDE_PROJECT_DIR:-.}"

plans=()

# Scan categorized plan directories (v5+): docs/plans/{category}/{name}/
if [ -d "$cwd/docs/plans" ]; then
  while IFS= read -r plan_file; do
    plan_dir=$(dirname "$plan_file")
    # Extract category/name from path: docs/plans/{cat}/{name}/{file}
    rel_path="${plan_dir#$cwd/docs/plans/}"
    category=$(echo "$rel_path" | cut -d'/' -f1)
    name=$(echo "$rel_path" | cut -d'/' -f2)

    # Skip if this is the legacy flat path (no category/name structure)
    if [ "$category" = "$name" ] || [ -z "$name" ]; then
      continue
    fi

    # Determine mode
    if [ -f "$plan_dir/manifest.md" ]; then
      mode="spec-driven"
      spec_count=$(ls "$plan_dir/specs/"*-spec.md 2>/dev/null | wc -l | tr -d ' ')
      plans+=("$category/$name ($mode, $spec_count specs)")
    elif [ -f "$plan_dir/task_plan.md" ]; then
      mode="task-based"
      plans+=("$category/$name ($mode)")
    fi
  done < <(find "$cwd/docs/plans" -mindepth 3 -maxdepth 3 \( -name manifest.md -o -name task_plan.md \) 2>/dev/null)
fi

# Check legacy flat paths (pre-v5 plans)
legacy_files=()
legacy_mode="none"

[ -f "$cwd/task_plan.md" ] && legacy_files+=("task_plan.md")
[ -f "$cwd/findings.md" ] && legacy_files+=("findings.md")
[ -f "$cwd/progress.md" ] && legacy_files+=("progress.md")

if [ -f "$cwd/docs/plans/manifest.md" ]; then
  # Only count as legacy if there's no category subdirectory structure
  parent_of_manifest=$(dirname "$cwd/docs/plans/manifest.md")
  if [ "$parent_of_manifest" = "$cwd/docs/plans" ]; then
    legacy_files+=("docs/plans/manifest.md")
    legacy_mode="spec-driven"
    spec_count=$(ls "$cwd/docs/plans/specs/"*-spec.md 2>/dev/null | wc -l | tr -d ' ')
    if [ "$spec_count" -gt 0 ]; then
      legacy_files+=("$spec_count spec files")
    fi
  fi
elif [ ${#legacy_files[@]} -gt 0 ]; then
  legacy_mode="task-based"
fi

# No plans found at all
if [ ${#plans[@]} -eq 0 ] && [ ${#legacy_files[@]} -eq 0 ]; then
  exit 0
fi

# Build output message
msg="[interactive-planning] "

if [ ${#plans[@]} -gt 0 ]; then
  plan_list=$(IFS=', '; echo "${plans[*]}")
  msg="${msg}Active plans: $plan_list."
fi

if [ ${#legacy_files[@]} -gt 0 ]; then
  file_list=$(IFS=', '; echo "${legacy_files[*]}")
  if [ ${#plans[@]} -gt 0 ]; then
    msg="${msg} Legacy plan also found ($legacy_mode): $file_list."
  else
    msg="${msg}Legacy plan detected ($legacy_mode): $file_list."
  fi
fi

# Extract current phase from any progress.md found
current_phase=""
if [ ${#plans[@]} -gt 0 ]; then
  # Check first categorized plan's progress
  first_progress=$(find "$cwd/docs/plans" -mindepth 3 -maxdepth 3 -name progress.md 2>/dev/null | head -1)
  if [ -n "$first_progress" ]; then
    current_phase=$(grep -m1 "Status.*in_progress" "$first_progress" 2>/dev/null || true)
  fi
elif [ -f "$cwd/progress.md" ]; then
  current_phase=$(grep -m1 "Status.*in_progress" "$cwd/progress.md" 2>/dev/null || true)
fi

if [ -n "$current_phase" ]; then
  msg="$msg Currently in progress: $current_phase."
fi

msg="$msg Use '/interactive-planning resume' to continue or '/interactive-planning status' for details."

echo "$msg"

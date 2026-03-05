# Handoff: {{ project.name }}

<!--
  FIXED-SIZE FILE: Must stay under 150 lines.
  Phase agents OVERWRITE Last Completed Phase and Current Phase sections.
  Phase agents APPEND to Architecture Decisions (truncate to 10 most recent if over limit).
  Phase agents update Workspace State to reflect current branch/commit.

  This is the ONLY file that phase runner agents read for inter-agent context.
  Do NOT read progress-log.md — it's append-only history for humans.
-->

## Project Context

- Type: {{ project.type }}
- Build: {{ project.build_cmd }}
- Test: {{ project.test_cmd }}

## Architecture Decisions

<!-- Append-only across phases. Each entry: "Phase N: decision". Truncate to 10 most recent if file exceeds 150 lines. -->

(none yet)

## Last Completed Phase

name: (none yet)
session: 0
status: not_started
summary: Project initialized. No phases completed.
key_files: []
decisions: []

## Current Phase

name: {{ current_phase.name }}
number: {{ current_phase.number }}
status: ready
criteria:
{% for c in current_phase.criteria %}
  - [ ] {{ c }}
{% endfor %}

## Workspace State

branch: (not yet created)
last_commit: (none)
uncommitted_changes: none
build_status: unknown

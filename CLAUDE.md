# CLAUDE.md

Claude Code plugin for file-based interactive planning with gate-driven user alignment.

## Codebase Overview

Two planning modes: **task-based** (single plan file, sequential phases) and **spec-driven** (multi-file specs with dependency DAG, topological sprint assignment). Uses `AskUserQuestion` for interactive gates, `TaskCreate`/`TaskUpdate` for progress tracking, and Manus-style file persistence across sessions.

**Stack**: Markdown skills/agents/commands, Bash hooks, Claude Code plugin system
**Structure**: Plugin manifest → command router → core skill (SKILL.md) → templates

For detailed architecture, see [docs/CODEBASE_MAP.md](docs/CODEBASE_MAP.md).

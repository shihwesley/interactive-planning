# Changelog

## 4.1.0 (2026-02-13)

Initial plugin release. Extracted from personal skill library and packaged as a distributable Claude Code plugin.

### Components
- **Skill**: Full interactive planning methodology with task-based and spec-driven modes
- **Command**: `/interactive-planning [status|resume|reset]` for session management
- **Agent**: `planning-advisor` auto-detects complex tasks and suggests planning
- **Hook**: SessionStart detection of existing planning files

### Features
- Two planning modes: task-based (single plan file) and spec-driven (multi-file specs with manifest)
- Interactive gates (AskUserQuestion) at every decision point
- Dependency DAG with topological sort for automatic sprint/phase grouping
- Native TaskCreate/TaskUpdate integration for structured progress tracking
- Session recovery via planning file detection
- 2-Action Rule for capturing research findings
- 3-Strike Protocol for error escalation

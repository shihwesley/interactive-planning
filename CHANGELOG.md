# Changelog

## 5.1.0 (2026-03-05)

### Added
- **Workflow contract** (`workflow.md`): declarative execution config with YAML frontmatter for retry behavior, between-phase gates, progress enforcement, and Liquid-style prompt templates.
- **Handoff file** (`handoff.md`): fixed-size inter-agent communication file (<150 lines) that phase runners read on start and overwrite on finish. Carries architecture decisions, last phase summary, and workspace state.
- **Progress log** (`progress-log.md`): append-only session history with structured entries (timestamps, files changed, commits, blockers). Phase agents never read it; TLDR hook summarizes for humans.
- **Project type gate**: Gate 1 now asks greenfield/brownfield/prototype, feeding into workflow.md config.
- **Continuation prompts**: retry logic passes attempt number and previous failure reason to the phase agent so it doesn't restart from scratch.
- **Between-phase gates**: configurable auto/manual/review modes in workflow.md.
- **Progress enforcement**: strict/warn/none modes that validate handoff.md was actually updated before marking a phase complete.
- Three new templates: `workflow-template.md`, `handoff-template.md`, `progress-log-template.md`.

### Changed
- Gate 4 summary now mentions the workflow contract files.
- Plan directory examples in README include `workflow.md`.

## 5.0.0 (2026-03-03)

### Breaking Changes
- Plan files now live in `docs/plans/{category}/{name}/` instead of flat `docs/plans/`. Legacy flat-path plans are detected and resumable but not migrated automatically.
- `findings.md` and `progress.md` moved inside the plan directory (no longer at project root).

### Added
- **Categorized plan directories**: 7 categories (general, feat, fix, refactor, review, test, polish) for multi-plan coexistence.
- **Auto-detection (Phase 0.5)**: Category and plan name inferred from user's request via keyword heuristics — no extra gate question.
- **Multi-plan session recovery**: Phase 0 scans `docs/plans/*/*/` and lists all active plans when multiple exist.
- **Targeted commands**: `resume feat/auth`, `status fix/login-crash`, `reset refactor/data-layer` — operate on specific plans.
- **`list` subcommand**: Table view of all active planning sessions with mode, category, and status.
- **`PLAN_DIR` variable**: All file paths in SKILL.md are parameterized, no more hardcoded `docs/plans/`.

### Changed
- Session hook scans categorized directories recursively instead of checking fixed paths.
- Manifest template includes `category`, `plan_name`, `plan_dir` in frontmatter.
- Spec template includes `plan` field linking to its parent plan.
- Planning advisor scans categorized directories and suggests category in output.
- Codebase map updated for v5 architecture.

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

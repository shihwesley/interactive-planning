---
name: {SPEC_NAME}
phase: {PHASE_NUMBER}
sprint: {SPRINT_NUMBER}
parent: {PARENT_SPEC_NAME or null}
depends_on: [{DEPENDENCY_SPEC_NAMES}]
status: draft
created: {DATE}
---

# {SPEC_TITLE}

## Overview
{1-2 sentences: what this spec covers and why it exists}

## Requirements
- [ ] REQ-1: {requirement}
- [ ] REQ-2: {requirement}

## Acceptance Criteria
- [ ] AC-1: {testable criterion}
- [ ] AC-2: {testable criterion}

## Technical Approach
{How this piece will be built}

## Files
| File | Action | Purpose |
|------|--------|---------|
| {path} | create/modify | {what and why} |

## Tasks
1. {Task derived from requirements}
2. {Task derived from requirements}

## Dependencies
- **Needs from {dep-spec}:** {what this spec consumes}
- **Provides to {downstream-spec}:** {what this spec produces}

## Open Questions
- {Anything unresolved -- triggers a checkpoint during execution}

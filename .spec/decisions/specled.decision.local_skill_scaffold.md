---
id: specled.decision.local_skill_scaffold
status: accepted
date: 2026-03-11
affects:
  - repo.governance
  - spec.system
  - specled.mix_tasks
---

# Local Skill Scaffold Supports Repo Usage

## Context

Initialized repositories need local guidance that helps agents maintain `.spec` consistently without hard-coding package-specific behavior into the main tool.

## Decision

`mix spec.init` scaffolds a thin local Skill for Spec Led Development when the interactive prompt is accepted. The local Skill explains repo usage, when to update current-truth subjects, when to add an ADR, and when `mix spec.check --base ...` should fail.

## Consequences

Repositories get project-local guidance without changing the core format. The upstream package keeps the reusable workflow, while local Skills carry repository-specific conventions.

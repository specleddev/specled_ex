---
id: specled.decision.declarative_current_truth
status: accepted
date: 2026-03-11
affects:
  - repo.governance
  - spec.system
  - specled.package
  - specled.mix_tasks
  - specled.status
  - specled.branch_guard
---

# Declarative Current Truth With Git History

## Context

Spec Led Development needs a durable current-state contract without turning `.spec/` into a second project tracker.

## Decision

Keep `.spec/specs/*.spec.md` as current truth only. Use Git branches, commits, and pull requests as the time dimension for change history. Store only durable cross-cutting ADRs under `.spec/decisions/*.md`.

## Consequences

The workspace stays declarative. Agents and humans update current truth directly, use ADRs for stable policy, and rely on `mix spec.check` plus Git review to catch missing co-changes.

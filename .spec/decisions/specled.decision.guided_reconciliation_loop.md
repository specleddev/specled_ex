---
id: specled.decision.guided_reconciliation_loop
status: accepted
date: 2026-03-20
affects:
  - repo.governance
  - spec.system
  - specled.package
  - specled.mix_tasks
  - specled.prime
  - specled.next
  - specled.branch_guard
  - specled.status
---

# Guided Reconciliation Before Strict Enforcement

## Context

Spec Led Development needs a gentler local loop for small changes, brownfield work, and regression fixes, especially when a maintainer is still learning the workspace.

Strict drift enforcement alone catches missing co-changes, but it does not tell the maintainer what to do next.

## Decision

Add a read-only guided reconciliation step before strict enforcement.

Use `mix spec.prime` at session start to combine workspace health, current-branch guidance, and the default local loop in one read-only output.

Use `mix spec.next` to inspect the current Git change set, point at the impacted subject or uncovered frontier, and suggest the next spec, proof, or ADR action.

Keep `.spec` authored and deterministic.

Keep branch guarding inside `mix spec.check` and use `mix spec.status` for frontier reporting, but do not let those commands auto-edit current truth.

## Consequences

The default local loop becomes: orient with `mix spec.prime` when entering a branch, make the change, tighten the proof, run `mix spec.next`, update current truth, then run `mix spec.check --base ...`.

Brownfield adoption becomes easier because uncovered frontier files are reported explicitly instead of being left implicit.

Branch-local planning notes such as `docs/plans/*.md` are not treated as current-truth policy surfaces.

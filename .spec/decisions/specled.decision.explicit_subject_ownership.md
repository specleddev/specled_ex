---
id: specled.decision.explicit_subject_ownership
status: accepted
date: 2026-03-11
affects:
  - repo.governance
  - specled.package
  - specled.index_state
  - specled.block_schema
  - specled.verification
  - specled.reporting
---

# Explicit Subject Ownership For Self-Hosted Internals

## Context

Spec Led Development can exercise internal helper modules indirectly through tests and workflows while still leaving those helpers unowned by any authored current-truth subject. That weakens self-hosting because the package source may be verified in practice without being represented clearly in `.spec/specs/`.

## Decision

Keep self-hosted package coverage explicit. Every shipped source module should belong to at least one meaningful current-truth subject, and low-level helpers should be grouped into coherent ownership subjects instead of left as accidental coverage.

## Consequences

The self-hosted `.spec/specs/` set may grow when the package adds new internal responsibilities. Coverage reports become easier to interpret because uncovered source files indicate real authored gaps rather than indirect test coverage hiding missing subject ownership.

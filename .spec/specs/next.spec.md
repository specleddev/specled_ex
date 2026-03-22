# Next

Guided reconciliation for the current Git change set.

## Intent

Give maintainers a deterministic, read-only next step after code, test, or docs changes.

```spec-meta
id: specled.next
kind: workflow
status: active
summary: Classifies the current change set, points at impacted subjects or uncovered frontier files, and suggests the next Spec Led step without writing current truth automatically.
surface:
  - lib/mix/tasks/spec.next.ex
  - lib/specled_ex/next.ex
  - lib/specled_ex/change_analysis.ex
  - skills/write-spec-led-specs/SKILL.md
  - priv/spec_init/README.md.eex
  - priv/spec_init/AGENTS.md.eex
  - test/mix/tasks/spec_next_task_test.exs
decisions:
  - specled.decision.declarative_current_truth
  - specled.decision.guided_reconciliation_loop
  - specled.decision.explicit_subject_ownership
```

## Requirements

```spec-requirements
- id: specled.next.change_classification
  statement: mix spec.next shall inspect the current Git change set, classify it as covered local, covered cross-cutting, uncovered frontier, or likely non-contract, and list the impacted subjects or uncovered policy files plus the next suggested commands.
  priority: must
  stability: evolving
- id: specled.next.reconciliation_status
  statement: mix spec.next shall report whether the branch is ready for check, still needs subject updates, still needs a durable ADR update, or needs a new subject.
  priority: should
  stability: evolving
- id: specled.next.bugfix_guidance
  statement: mix spec.next --bugfix shall prefer regression proof first and direct the maintainer to confirm whether the current subject wording already captures the fix before adding new spec churn.
  priority: should
  stability: evolving
- id: specled.next.read_only
  statement: mix spec.next shall stay read-only and return guidance output without writing current-truth files or derived state.
  priority: must
  stability: evolving
```

## Verification

```spec-verification
- kind: command
  target: mix test test/mix/tasks/spec_next_task_test.exs
  execute: true
  covers:
    - specled.next.change_classification
    - specled.next.reconciliation_status
    - specled.next.bugfix_guidance
    - specled.next.read_only
```

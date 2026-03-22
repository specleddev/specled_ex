# Branch Guard

Diff-aware co-change validation for current-truth subject specs and durable ADRs.

## Intent

Catch code, docs, and test changes that move ahead of current-truth specs or skip a needed cross-cutting ADR update.

```spec-meta
id: specled.branch_guard
kind: workflow
status: active
summary: Uses the current Git change set to enforce subject co-changes and cross-cutting ADR updates during the final local check.
surface:
  - lib/specled_ex/branch_check.ex
  - lib/specled_ex/coverage.ex
  - lib/mix/tasks/spec.check.ex
decisions:
  - specled.decision.declarative_current_truth
  - specled.decision.guided_reconciliation_loop
```

## Requirements

```spec-requirements
- id: specled.branch_guard.subject_cochange
  statement: The branch guard inside mix spec.check shall fail when changed code, tests, guides, templates, skills, or governed package files are not matched by current-truth subject spec updates for the impacted subjects, including unmapped changed policy files outside current subject coverage.
  priority: must
  stability: evolving
- id: specled.branch_guard.cross_cutting_decision
  statement: The branch guard inside mix spec.check shall fail with an error finding when a cross-cutting change spans multiple impacted subjects without a matching ADR update.
  priority: must
  stability: evolving
- id: specled.branch_guard.guidance_output
  statement: The branch guard inside mix spec.check shall append additive guidance that reports the change type, impacted subjects or uncovered policy files, and the suggested mix spec.next command without changing its enforcement semantics.
  priority: should
  stability: evolving
- id: specled.branch_guard.plan_docs_excluded
  statement: The branch guard inside mix spec.check shall ignore branch-local planning notes under docs/plans/ when evaluating policy co-changes.
  priority: should
  stability: evolving
```

## Verification

```spec-verification
- kind: command
  target: mix test test/mix/tasks/spec_tasks_test.exs
  execute: true
  covers:
    - specled.branch_guard.subject_cochange
    - specled.branch_guard.cross_cutting_decision
    - specled.branch_guard.guidance_output
    - specled.branch_guard.plan_docs_excluded
```

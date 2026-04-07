# Status

Coverage and weak-spot reporting for the current Spec Led Development workspace.

## Intent

Summarize what the workspace covers now without introducing persistent in-flight planning artifacts.

```spec-meta
id: specled.status
kind: workflow
status: active
summary: Builds current-state summaries for coverage, verification strength, weak spots, and ADR usage.
surface:
  - lib/specled_ex/status.ex
  - lib/specled_ex/coverage.ex
  - lib/mix/tasks/spec.status.ex
decisions:
  - specled.decision.declarative_current_truth
  - specled.decision.explicit_subject_ownership
  - specled.decision.guided_reconciliation_loop
  - specled.decision.no_app_start
```

## Requirements

```spec-requirements
- id: specled.status.coverage_summary
  statement: mix spec.status shall summarize source, guide, and test coverage plus weak spots by subject from the current workspace, using executed command proof by default unless explicitly disabled.
  priority: should
  stability: evolving
- id: specled.status.frontier_summary
  statement: mix spec.status shall include frontier data for uncovered source, guide, and test files plus short next-gap hints for brownfield adoption.
  priority: should
  stability: evolving
- id: specled.status.decision_index
  statement: state output and mix spec.status shall summarize indexed ADRs and subject-to-ADR references.
  priority: must
  stability: evolving
```

## Verification

```spec-verification
- kind: command
  target: mix test test/specled_ex/index_state_test.exs test/mix/tasks/spec_tasks_test.exs test/mix/tasks/spec_status_task_test.exs
  execute: true
  covers:
    - specled.status.coverage_summary
    - specled.status.frontier_summary
    - specled.status.decision_index
```

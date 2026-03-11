# Reporting

Coverage and weak-spot reporting for the current Spec Led Development workspace.

## Intent

Summarize what the workspace covers now without introducing persistent in-flight planning artifacts.

```spec-meta
id: specled.reporting
kind: workflow
status: active
summary: Builds current-state summaries for coverage, verification strength, weak spots, and ADR usage.
surface:
  - lib/specled_ex/report.ex
  - lib/specled_ex/coverage.ex
  - lib/specled_ex.ex
  - lib/mix/tasks/spec.report.ex
decisions:
  - specled.decision.declarative_current_truth
  - specled.decision.explicit_subject_ownership
```

## Requirements

```spec-requirements
- id: specled.reporting.coverage_summary
  statement: spec.report shall summarize source, guide, and test coverage plus weak spots by subject from the current workspace, using executed command proof by default unless explicitly disabled.
  priority: should
  stability: evolving
- id: specled.reporting.decision_index
  statement: state output and spec.report shall summarize indexed ADRs and subject-to-ADR references.
  priority: must
  stability: evolving
```

## Verification

```spec-verification
- kind: command
  target: mix test test/specled_ex/index_state_test.exs test/mix/tasks/spec_tasks_test.exs test/mix/tasks/spec_report_task_test.exs
  execute: true
  covers:
    - specled.reporting.coverage_summary
    - specled.reporting.decision_index
```

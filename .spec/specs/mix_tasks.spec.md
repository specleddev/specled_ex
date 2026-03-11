# Mix Tasks

User-facing commands for the Spec Led Development workflow.

## Intent

Provide four Mix tasks that cover the full local workflow:
scaffold, index, verify, and strict check.

```spec-meta
id: specled.mix_tasks
kind: workflow
status: active
summary: Mix tasks for scaffolding, planning, verifying, reporting on, and diff-checking Spec Led Development workspaces.
surface:
  - lib/mix/tasks/spec.init.ex
  - lib/mix/tasks/spec.plan.ex
  - lib/mix/tasks/spec.verify.ex
  - lib/mix/tasks/spec.check.ex
  - lib/mix/tasks/spec.adr.new.ex
  - lib/mix/tasks/spec.report.ex
  - lib/mix/tasks/spec.diffcheck.ex
decisions:
  - specled.decision.declarative_current_truth
  - specled.decision.local_skill_scaffold
```

## Requirements

```spec-requirements
- id: specled.tasks.init_scaffold
  statement: mix spec.init shall create the canonical .spec/ workspace with README.md, AGENTS.md, decisions/README.md, spec_system.spec.md, and package.spec.md.
  priority: must
  stability: stable
- id: specled.tasks.init_local_skill
  statement: In interactive runs, mix spec.init shall offer to scaffold a local Skill for Spec Led Development and write it when the prompt is accepted.
  priority: should
  stability: evolving
- id: specled.tasks.adr_new_scaffold
  statement: mix spec.adr.new shall scaffold an ADR under .spec/decisions with the required frontmatter and body sections.
  priority: should
  stability: evolving
- id: specled.tasks.plan_writes_state
  statement: mix spec.plan shall build the authored subject and decision index and write .spec/state.json.
  priority: must
  stability: stable
- id: specled.tasks.verify_findings
  statement: mix spec.verify shall validate specs, derive findings, and write .spec/state.json with a verification report before returning.
  priority: must
  stability: stable
- id: specled.tasks.verify_exit_status
  statement: mix spec.verify shall exit non-zero whenever the generated verification report status is fail.
  priority: must
  stability: stable
- id: specled.tasks.check_strict_gate
  statement: mix spec.check shall run planning and strict verification, failing on any errors or warnings.
  priority: must
  stability: stable
- id: specled.tasks.report_summary
  statement: mix spec.report shall summarize coverage, verification strength, weak spots, and ADR usage for the current workspace, executing command verifications by default unless explicitly opted out.
  priority: should
  stability: evolving
- id: specled.tasks.diffcheck_gate
  statement: mix spec.diffcheck shall inspect the current Git diff and fail when changed code, docs, or tests are missing required subject or ADR co-changes.
  priority: must
  stability: evolving
```

## Verification

```spec-verification
- kind: command
  target: mix test test/mix/tasks/spec_tasks_test.exs test/mix/tasks/spec_report_task_test.exs
  execute: true
  covers:
    - specled.tasks.init_scaffold
    - specled.tasks.init_local_skill
    - specled.tasks.adr_new_scaffold
    - specled.tasks.plan_writes_state
    - specled.tasks.verify_findings
    - specled.tasks.verify_exit_status
    - specled.tasks.check_strict_gate
    - specled.tasks.report_summary
    - specled.tasks.diffcheck_gate
```

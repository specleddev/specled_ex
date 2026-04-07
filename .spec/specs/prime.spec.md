# Prime

Session-start context for agents and maintainers.

## Intent

Give one read-only command that helps a maintainer or agent understand the current workspace and branch before editing current truth.

```spec-meta
id: specled.prime
kind: workflow
status: active
summary: Combines workspace status, current-branch guidance, and the default local loop into one session-start command.
surface:
  - lib/mix/tasks/spec.prime.ex
  - lib/specled_ex/prime.ex
  - test/mix/tasks/spec_prime_task_test.exs
decisions:
  - specled.decision.declarative_current_truth
  - specled.decision.guided_reconciliation_loop
  - specled.decision.no_app_start
```

## Requirements

```spec-requirements
- id: specled.prime.session_context
  statement: mix spec.prime shall provide a read-only session-start summary that combines workspace status, current-branch guidance, and the default local loop for the current repository.
  priority: should
  stability: evolving
- id: specled.prime.command_execution_default
  statement: mix spec.prime shall keep command verification execution off by default and only execute eligible command verifications when --run-commands is passed.
  priority: should
  stability: evolving
- id: specled.prime.machine_output
  statement: mix spec.prime shall support JSON output that nests the workspace status report, current-branch guidance, and loop steps for agent consumption.
  priority: should
  stability: evolving
```

## Verification

```spec-verification
- kind: command
  target: mix test test/mix/tasks/spec_prime_task_test.exs
  execute: true
  covers:
    - specled.prime.session_context
    - specled.prime.command_execution_default
    - specled.prime.machine_output
```

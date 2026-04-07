# Mix Tasks

User-facing commands for the Spec Led Development workflow.

## Intent

Provide the user-facing Mix tasks that scaffold, guide, summarize, and strictly enforce the local Spec Led workflow.

```spec-meta
id: specled.mix_tasks
kind: workflow
status: active
summary: Mix tasks for scaffolding, session-start priming, indexing, guiding, validating, summarizing, and strictly checking Spec Led Development workspaces.
surface:
  - lib/mix/tasks/spec.init.ex
  - lib/mix/tasks/spec.prime.ex
  - lib/mix/tasks/spec.next.ex
  - lib/mix/tasks/spec.check.ex
  - lib/mix/tasks/spec.status.ex
  - lib/mix/tasks/spec.decision.new.ex
  - lib/mix/tasks/spec.index.ex
  - lib/mix/tasks/spec.validate.ex
  - lib/specled_ex/prime.ex
  - priv/spec_init/agents/skills/spec-led-development/SKILL.md.eex
  - priv/spec_init/specs/spec_system.spec.md.eex
  - skills/write-spec-led-specs/references/authoring-reference.md
  - test_support/specled_ex_case.ex
decisions:
  - specled.decision.declarative_current_truth
  - specled.decision.local_skill_scaffold
  - specled.decision.guided_reconciliation_loop
  - specled.decision.no_app_start
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
- id: specled.tasks.decision_new_scaffold
  statement: mix spec.decision.new shall scaffold an ADR under .spec/decisions with the required frontmatter and body sections.
  priority: should
  stability: evolving
- id: specled.tasks.index_writes_state
  statement: mix spec.index shall build the authored subject and decision index and write .spec/state.json.
  priority: must
  stability: stable
- id: specled.tasks.prime_context
  statement: mix spec.prime shall provide a read-only session-start summary that combines workspace status, current-branch guidance, and the default local loop without writing current-truth files or derived state.
  priority: should
  stability: evolving
- id: specled.tasks.next_guidance
  statement: mix spec.next shall provide a read-only guided reconciliation step that points at the next subject, proof, or ADR update for the current Git change set and tell the maintainer when the branch is ready for the full local check.
  priority: should
  stability: evolving
- id: specled.tasks.prime_json
  statement: mix spec.prime shall support JSON output for agent consumption and shall only execute eligible command verifications when --run-commands is passed.
  priority: should
  stability: evolving
- id: specled.tasks.validate_findings
  statement: mix spec.validate shall validate specs, derive findings, and write .spec/state.json with a verification report before returning.
  priority: must
  stability: stable
- id: specled.tasks.validate_exit_status
  statement: mix spec.validate shall exit non-zero whenever the generated verification report status is fail.
  priority: must
  stability: stable
- id: specled.tasks.check_strict_gate
  statement: mix spec.check shall run indexing, strict validation, and branch-aware co-change enforcement, failing on any errors or warnings.
  priority: must
  stability: stable
- id: specled.tasks.status_summary
  statement: mix spec.status shall summarize coverage, verification strength, weak spots, and ADR usage for the current workspace, executing command verifications by default unless explicitly opted out.
  priority: should
  stability: evolving
- id: specled.tasks.no_app_start
  statement: No mix spec.* task shall call Mix.Task.run("app.start") or otherwise require the host OTP application to be running, since spec tasks perform only file I/O, Git CLI calls, and in-memory parsing.
  priority: must
  stability: stable
```

## Verification

```spec-verification
- kind: command
  target: mix test test/mix/tasks/spec_tasks_test.exs test/mix/tasks/spec_status_task_test.exs test/mix/tasks/spec_next_task_test.exs test/mix/tasks/spec_prime_task_test.exs
  execute: true
  covers:
    - specled.tasks.init_scaffold
    - specled.tasks.init_local_skill
    - specled.tasks.decision_new_scaffold
    - specled.tasks.index_writes_state
    - specled.tasks.prime_context
    - specled.tasks.prime_json
    - specled.tasks.next_guidance
    - specled.tasks.validate_findings
    - specled.tasks.validate_exit_status
    - specled.tasks.check_strict_gate
    - specled.tasks.status_summary
    - specled.tasks.no_app_start
```

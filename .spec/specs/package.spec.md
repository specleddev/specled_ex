# specled_ex

Local tooling package for Spec Led Development repositories.

## Intent

Provide Mix tasks and library functions that let Elixir projects
adopt Spec Led Development with a single dependency.

```spec-meta
id: specled.package
kind: package
status: active
summary: Elixir package for Spec Led Development. Provides Mix tasks to scaffold, index, verify, report on, and diff-check authored specs.
surface:
  - README.md
  - CHANGELOG.md
  - mix.exs
  - lib/specled_ex.ex
decisions:
  - specled.decision.declarative_current_truth
  - specled.decision.local_skill_scaffold
  - specled.decision.explicit_subject_ownership
```

## Requirements

```spec-requirements
- id: specled.package.mix_tasks
  statement: The package shall provide mix spec.init, mix spec.plan, mix spec.verify, mix spec.check, mix spec.adr.new, mix spec.report, and mix spec.diffcheck as user-facing commands.
  priority: must
  stability: stable
- id: specled.package.index_and_state
  statement: The package shall index authored subject specs, index durable ADRs, and write derived state to .spec/state.json.
  priority: must
  stability: stable
- id: specled.package.declarative_governance
  statement: The package shall keep `.spec` declarative and current-state only, using ADRs for durable cross-cutting policy and Git history for change over time.
  priority: must
  stability: stable
```

## Verification

```spec-verification
- kind: command
  target: mix test test/specled_ex_test.exs test/specled_ex/index_state_test.exs
  execute: true
  covers:
    - specled.package.index_and_state
    - specled.package.declarative_governance
- kind: command
  target: >-
    mix run -e 'Mix.Task.load_all(); Enum.each(~w(spec.init spec.plan spec.verify spec.check spec.adr.new spec.report spec.diffcheck), fn task -> Mix.Task.get(task) || raise("missing #{task}") end)'
  execute: true
  covers:
    - specled.package.mix_tasks
```

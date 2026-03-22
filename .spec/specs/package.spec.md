# specled_ex

Local tooling package for Spec Led Development repositories.

## Intent

Provide Mix tasks and library functions that let Elixir projects
adopt Spec Led Development with a single dependency.

```spec-meta
id: specled.package
kind: package
status: active
summary: Elixir package for Spec Led Development. Provides Mix tasks to scaffold, orient, index, guide, validate, summarize, and strictly check authored specs.
surface:
  - README.md
  - CHANGELOG.md
  - mix.exs
  - lib/specled_ex.ex
decisions:
  - specled.decision.declarative_current_truth
  - specled.decision.local_skill_scaffold
  - specled.decision.explicit_subject_ownership
  - specled.decision.guided_reconciliation_loop
```

## Requirements

```spec-requirements
- id: specled.package.mix_tasks
  statement: The package shall provide mix spec.init, mix spec.prime, mix spec.next, mix spec.check, mix spec.status, mix spec.decision.new, mix spec.index, and mix spec.validate as user-facing commands.
  priority: must
  stability: stable
- id: specled.package.default_local_loop
  statement: The package README shall teach mix spec.prime as the session-start context command, a default local loop centered on mix spec.next and mix spec.check, explain the ready-for-check decision, reserve ADRs for durable cross-cutting policy, and present mix spec.status as occasional plus mix spec.index and mix spec.validate as advanced plumbing.
  priority: should
  stability: evolving
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
- kind: readme_file
  target: README.md
  covers:
    - specled.package.default_local_loop
- kind: command
  target: >-
    mix run -e 'Mix.Task.load_all(); Enum.each(~w(spec.init spec.prime spec.next spec.check spec.status spec.decision.new spec.index spec.validate), fn task -> Mix.Task.get(task) || raise("missing #{task}") end)'
  execute: true
  covers:
    - specled.package.mix_tasks
```

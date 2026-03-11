# specled_ex

Local tooling package for Spec Led Development repositories.

## Intent

Provide Mix tasks and library functions that let Elixir projects
adopt Spec Led Development with a single dependency.

```spec-meta
id: specled.package
kind: package
status: active
summary: Elixir package for Spec Led Development. Provides Mix tasks to scaffold, index, verify, and check authored specs.
surface:
  - mix.exs
  - lib/specled_ex.ex
```

## Requirements

```spec-requirements
- id: specled.package.mix_tasks
  statement: The package shall provide mix spec.init, mix spec.plan, mix spec.verify, and mix spec.check as user-facing commands.
  priority: must
  stability: stable
- id: specled.package.index_and_state
  statement: The package shall index authored spec files and write derived state to .spec/state.json.
  priority: must
  stability: stable
```

## Verification

```spec-verification
- kind: source_file
  target: lib/specled_ex.ex
  covers:
    - specled.package.index_and_state
- kind: source_file
  target: lib/mix/tasks/spec.init.ex
  covers:
    - specled.package.mix_tasks
- kind: source_file
  target: lib/mix/tasks/spec.verify.ex
  covers:
    - specled.package.mix_tasks
```

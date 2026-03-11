# Index And State

Index building and canonical state persistence for the Spec Led Development workspace.

## Intent

Define how the package discovers authored current-truth subjects and ADRs, then
persists a stable `.spec/state.json` artifact for later inspection and diffing.

```spec-meta
id: specled.index_state
kind: workflow
status: active
summary: Builds the authored index and writes canonical derived state for the workspace.
surface:
  - lib/specled_ex/index.ex
  - lib/specled_ex.ex
  - lib/specled_ex/json.ex
decisions:
  - specled.decision.declarative_current_truth
  - specled.decision.explicit_subject_ownership
```

## Requirements

```spec-requirements
- id: specled.index.subject_and_decision_index
  statement: Index building shall discover authored subject specs and authored ADRs, detect the canonical workspace directories, and summarize indexed counts without treating `decisions/README.md` as an ADR.
  priority: must
  stability: stable
- id: specled.index.canonical_state_output
  statement: State writing shall normalize indexed entities, findings, verification data, and decisions into a canonical `.spec/state.json` artifact with stable ordering and no volatile persisted fields.
  priority: must
  stability: stable
- id: specled.index.json_resilience
  statement: JSON state helpers shall return an empty map for missing or invalid files, create parent directories on write, and skip rewriting identical canonical bytes.
  priority: must
  stability: stable
```

## Verification

```spec-verification
- kind: command
  target: mix test test/specled_ex_test.exs test/specled_ex/index_state_test.exs test/specled_ex/json_test.exs
  execute: true
  covers:
    - specled.index.subject_and_decision_index
    - specled.index.canonical_state_output
    - specled.index.json_resilience
```

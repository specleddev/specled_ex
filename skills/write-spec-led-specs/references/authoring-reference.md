# Spec Authoring Reference

## Subject Template

````markdown
# Subject Title

One or two sentences that describe the subject boundary.

## Intent

Explain what the subject covers and why it matters.

```spec-meta
id: package.subject
kind: module
status: active
summary: Short summary of the contract.
surface:
  - lib/path/to/file.ex
```

## Requirements

```spec-requirements
- id: package.subject.behavior
  statement: Describe the required behavior.
  priority: must
  stability: stable
```

## Scenarios

```spec-scenarios
- id: package.subject.example_flow
  given:
    - the relevant precondition
  when:
    - the triggering action happens
  then:
    - the observable result is true
  covers:
    - package.subject.behavior
```

## Verification

```spec-verification
- kind: source_file
  target: lib/path/to/file.ex
  covers:
    - package.subject.behavior
    - package.subject.example_flow
```

## Exceptions

```spec-exceptions
- id: package.subject.deferred_coverage
  covers:
    - package.subject.behavior
  reason: Explain why verification is intentionally deferred.
```
````

## Block Rules

- Use the first Markdown H1 as the subject title.
- Use each fenced block tag at most once per file. A second `spec-meta`, `spec-requirements`, `spec-scenarios`, `spec-verification`, or `spec-exceptions` block becomes a parse error.
- Make `spec-meta` a mapping with at least `id`, `kind`, and `status`. Additional keys such as `summary` and `surface` are preserved.
- Make `spec-requirements`, `spec-scenarios`, `spec-verification`, and `spec-exceptions` decode to lists.
- Prefer YAML. JSON also parses because the implementation uses `YamlElixir`, but YAML matches the repository examples.

## Field Rules

- Use ids that match `^[a-z0-9][a-z0-9._-]*$`.
- Make requirement entries include `id` and `statement`.
- Make scenario entries include `id`, `covers`, `given`, `when`, and `then`. Keep `given`, `when`, and `then` non-empty to avoid warnings.
- Make verification entries include `kind`, `target`, and `covers`. Add `execute: true` only when the command is intended to run under `mix spec.verify --run_commands`.
- Make exception entries include `id`, `covers`, and `reason`.

## Coverage Rules

- Point each scenario `covers` entry at a requirement id from the same repository.
- Point each verification `covers` entry at a requirement id and any scenario ids it demonstrates.
- Make every requirement appear in at least one verification `covers` list or one exception `covers` list. Otherwise verification emits `requirement_without_verification`.
- Use repository-root-relative file paths in verification `target`.
- Prefer `source_file`, `test_file`, `guide_file`, `readme_file`, and `workflow_file` for file-backed evidence. `command` is also supported.

## Common Findings And Fixes

- `missing_meta_field`: add the missing `id`, `kind`, or `status` in `spec-meta`.
- `parse_error`: fix invalid YAML / JSON or remove duplicate block tags.
- `missing_requirement_id` or `missing_scenario_id`: add the missing entry id.
- `duplicate_subject_id`, `duplicate_requirement_id`, `duplicate_scenario_id`, `duplicate_exception_id`: rename the id so it is unique for that kind across the repository.
- `invalid_id_format`: rename the id to lowercase letters, digits, dots, underscores, and hyphens only.
- `scenario_unknown_cover`: change the scenario `covers` list to reference real requirement ids.
- `scenario_missing_given`, `scenario_missing_when`, `scenario_missing_then`: supply non-empty lists for the missing scenario step.
- `verification_unknown_cover`: change the verification `covers` list to reference real requirement or scenario ids.
- `verification_missing_target` or `verification_missing_command`: add the missing `target`.
- `verification_target_missing`: point at an existing file or pick a different verification kind.

## Project Patterns

- Follow the repository's naming style: subject ids like `specled.parser`, requirement ids like `specled.parser.standard_blocks`, and scenario ids like `specled.verify.uncovered_requirement`.
- Keep prose short and concrete. Put normative language in `statement`, not in the surrounding paragraphs.
- Add new subjects alongside neighboring files in `.spec/specs/` instead of creating nested directories.

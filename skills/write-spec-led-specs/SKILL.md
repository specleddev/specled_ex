---
name: write-spec-led-specs
description: Draft, revise, and validate authored Spec Led Development subject specs for repositories that use `.spec/specs/*.spec.md` files and `mix spec.*` tasks. Use when Codex needs to create a new subject spec, update `spec-meta`, `spec-requirements`, `spec-scenarios`, `spec-verification`, or `spec-exceptions` blocks, repair `mix spec.verify` or `mix spec.check` findings, or align `.spec` files with implementation, tests, and docs changes.
---

# Write Spec Led Specs

## Overview

Author `.spec/specs/*.spec.md` files that match this package's parser and verifier. Keep every claim grounded in repository evidence, prefer YAML fenced blocks, and leave the workspace passing `mix spec.verify --debug` and `mix spec.check`.

## Workflow

1. Confirm the workspace.
   - Run `mix spec.init` if `.spec/` is missing.
   - Read `.spec/README.md` and neighboring subject specs before drafting a new file.
2. Gather evidence.
   - Read the code, tests, docs, and Mix tasks that define the behavior.
   - Reuse the repository's naming patterns for subject ids and requirement ids.
3. Choose the subject boundary.
   - Keep one subject per file.
   - Prefer file names that match the subject, such as `.spec/specs/parser.spec.md`.
   - Split unrelated concerns into separate subject files instead of mixing them.
4. Draft or revise the subject.
   - Start with `# Title`, brief prose, and then fenced structured blocks.
   - Include exactly one `spec-meta` block and at most one block for each other spec tag.
   - Put normative statements in `spec-requirements`.
   - Add `spec-scenarios` only when behavior is easier to understand as `given` / `when` / `then`.
   - Add `spec-verification` entries for the evidence that covers each requirement or scenario.
   - Prefer command verifications for behavioral proof when the target file does not already carry stable `covers:` markers for the ids it names.
   - Add `spec-exceptions` only when a requirement is intentionally not verified yet and the reason should suppress the uncovered-requirement warning.
5. Validate and tighten.
   - Run `mix spec.verify --debug` after edits.
   - Fix warnings as well as errors; `mix spec.check` runs strict verification and fails on both.
   - Run `mix spec.check` once the subject is complete.

## Authoring Rules

- Prefer YAML inside fenced blocks. The parser also accepts JSON, but the repository's authored specs use YAML and it is easier to maintain.
- Use stable lowercase ids that match `^[a-z0-9][a-z0-9._-]*$`.
- Keep subject ids, requirement ids, scenario ids, and exception ids unique across the repository for their kind.
- Give each requirement a concrete `statement`.
- Make each scenario `covers` list point only at requirement ids.
- Make each verification `covers` list point at requirement ids and any scenario ids it demonstrates.
- Use repository-root-relative paths in verification `target`.
- Prefer canonical verification kinds such as `source_file`, `test_file`, `guide_file`, `readme_file`, `workflow_file`, or `command`.
- Keep `summary`, `surface`, and prose aligned with files that actually exist.

## Reference

Read [references/authoring-reference.md](references/authoring-reference.md) when you need the block template for a new subject, field-by-field rules, verifier failure modes, or examples of good coverage structure.

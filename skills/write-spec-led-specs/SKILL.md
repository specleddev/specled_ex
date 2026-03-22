---
name: write-spec-led-specs
description: Draft, revise, and validate authored Spec Led Development subject specs for repositories that use `.spec/specs/*.spec.md` files and `mix spec.*` tasks. Use when Codex needs to create a new subject spec, update `spec-meta`, `spec-requirements`, `spec-scenarios`, `spec-verification`, or `spec-exceptions` blocks, connect a subject to durable ADRs, repair `mix spec.validate` or `mix spec.check` findings, or align `.spec` files with implementation, tests, and docs changes.
---

# Write Spec Led Specs

## Overview

Author `.spec/specs/*.spec.md` files that match this package's parser and verifier. Keep every claim grounded in repository evidence, prefer YAML fenced blocks, start with `mix spec.prime` when you are entering a workspace, and use `mix spec.next` to reconcile code, tests, docs, and current truth before you finish with `mix spec.check`.

## Workflow

1. Confirm the workspace.
   - Run `mix spec.init` if `.spec/` is missing.
   - Run `mix spec.prime --base HEAD` when you are entering an existing repository or branch.
   - Read `.spec/README.md`, `.spec/decisions/README.md` when present, and neighboring subject specs before drafting a new file.
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
   - Add `spec-meta.decisions` only when the subject depends on a durable cross-cutting ADR in `.spec/decisions/*.md`.
5. Validate and tighten.
   - After code, docs, or tests change, run `mix spec.next`.
   - For a regression fix, run `mix spec.next --bugfix`.
   - If next says `ready for check`, move to `mix spec.check --base ...`.
   - If next says `needs subject updates`, update the named subject before you finish.
   - Run `mix spec.validate --debug` after edits when you need low-level verifier output.
   - Fix warnings as well as errors; `mix spec.check` runs strict verification and fails on both.
   - Run `mix spec.check --base ...` once the subject is complete.

## Authoring Rules

- Prefer YAML inside fenced blocks. The parser also accepts JSON, but the repository's authored specs use YAML and it is easier to maintain.
- Use stable lowercase ids that match `^[a-z0-9][a-z0-9._-]*$`.
- Keep subject ids, requirement ids, scenario ids, and exception ids unique across the repository for their kind.
- Give each requirement a concrete `statement`.
- Make each scenario `covers` list point only at requirement ids.
- Make each verification `covers` list point at requirement ids and any scenario ids it demonstrates.
- Use repository-root-relative paths in verification `target`.
- Prefer canonical verification kinds such as `source_file`, `test_file`, `guide_file`, `readme_file`, `workflow_file`, or `command`.
- Use `.spec/decisions/*.md` only for durable cross-cutting policy. Keep `.spec` declarative and use Git history for the timeline of change.
- Keep `summary`, `surface`, and prose aligned with files that actually exist.

## Reference

Read [references/authoring-reference.md](references/authoring-reference.md) when you need the block template for a new subject, field-by-field rules, verifier failure modes, or examples of good coverage structure.

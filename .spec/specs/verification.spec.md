# Verification

The verifier validates authored specs and derives findings.

## Intent

Take an indexed set of authored specs, validate structure and references,
and produce a verification report with findings. This is the core of
the intent verification loop.

```spec-meta
id: specled.verification
kind: workflow
status: active
summary: Validates authored specs, checks references, derives findings, and writes state.
surface:
  - lib/specled_ex/verifier.ex
  - lib/specled_ex/verification_strength.ex
  - lib/specled_ex/decision_parser.ex
  - lib/specled_ex/schema/decision.ex
decisions:
  - specled.decision.declarative_current_truth
  - specled.decision.file_backed_linked_strength
  - specled.decision.explicit_subject_ownership
```

## Requirements

```spec-requirements
- id: specled.verify.meta_required
  statement: Verification shall emit errors when a subject is missing spec-meta id, kind, or status.
  priority: must
  stability: stable
- id: specled.verify.reference_checks
  statement: Verification shall detect duplicate subject ids, duplicate requirement ids, unresolved scenario covers, and unresolved verification covers.
  priority: must
  stability: stable
- id: specled.verify.coverage_warnings
  statement: Verification shall warn when a requirement has no covering verification entry.
  priority: must
  stability: stable
- id: specled.verify.target_existence
  statement: Verification shall warn when a file-based verification target does not exist on disk.
  priority: should
  stability: stable
- id: specled.verify.malformed_entries_nonfatal
  statement: Verification shall ignore malformed non-map parsed block entries, rely on recorded parse errors, and continue producing a report.
  priority: must
  stability: stable
- id: specled.verify.decision_governance
  statement: Verification shall validate ADR frontmatter, required ADR sections, ADR affects references, supersession links, and subject decision references.
  priority: must
  stability: evolving
- id: specled.verify.strength_semantics
  statement: Verification strength ordering shall treat `claimed`, `linked`, and `executed` as an ordered proof scale and use that ordering to enforce effective minimum strength thresholds.
  priority: must
  stability: stable
```

## Scenarios

```spec-scenarios
- id: specled.verify.uncovered_requirement
  given:
    - a spec with a requirement that has no covering verification
  when:
    - verification runs
  then:
    - a warning finding is produced for the uncovered requirement
  covers:
    - specled.verify.coverage_warnings
- id: specled.verify.missing_target
  given:
    - a spec with a source_file verification pointing to a path that does not exist
  when:
    - verification runs
  then:
    - a warning finding is produced for the missing target
  covers:
    - specled.verify.target_existence
- id: specled.verify.malformed_entry_report
  given:
    - an indexed subject containing malformed parsed block entries and parse errors
  when:
    - verification runs
  then:
    - the report includes the parse error finding
    - verification does not crash
  covers:
    - specled.verify.malformed_entries_nonfatal
```

## Verification

```spec-verification
- kind: command
  target: mix test test/specled_ex/verifier_test.exs test/specled_ex/verification_strength_test.exs
  execute: true
  covers:
    - specled.verify.meta_required
    - specled.verify.reference_checks
    - specled.verify.coverage_warnings
    - specled.verify.target_existence
    - specled.verify.malformed_entries_nonfatal
    - specled.verify.decision_governance
    - specled.verify.strength_semantics
```

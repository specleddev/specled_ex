# SpecLedEx

Local helper package for Spec Led Development repositories.

The commands make the most sense when you group them by job instead of reading
them as one flat list.

## Session-Start Command

Use this when you are entering a repository, handing work to an agent, or
getting your bearings on an in-flight branch:

- `mix spec.prime`
  - prints one read-only session-start snapshot
  - combines workspace health, current-branch guidance, and the default local loop
  - skips `kind: command` execution by default; add `--run-commands` when you want executed proof in the embedded status summary

## Core Commands

These are the commands most maintainers should learn first:

- `mix spec.init`
  - scaffolds `.spec/` with starter files, including `README.md`, `AGENTS.md`, and `decisions/README.md`
  - in interactive runs, can also scaffold a local Skill for Spec Led Development
  - keeps `.spec` declarative and current-state only
- `mix spec.next`
  - reads the current Git change set and points at the next subject, proof, or ADR update to make
  - stays read-only in this release
  - supports `--bugfix` for regression-first guidance
- `mix spec.check`
  - runs the full local gate before you finish
  - updates derived state, validates current truth, and enforces branch coherence
  - enables `kind: command` execution by default; use `--no-run-commands` to opt out

## Occasional Commands

These are helpful, but they are not part of the default local loop:

- `mix spec.status`
  - summarizes source, guide, and test coverage, verification strength, weak spots, and ADR usage
  - useful for brownfield adoption and maintenance review
- `mix spec.decision.new`
  - scaffolds a durable ADR under `.spec/decisions/`
  - use it only when the change is durable and cross-cutting

## Advanced Commands

These are low-level plumbing commands. They are useful for debugging and tooling,
but they are not where a junior developer should start:

- `mix spec.index`
  - reads `.spec/specs/*.spec.md` and `.spec/decisions/*.md`
  - updates `.spec/state.json` with subject and ADR index data
- `mix spec.validate`
  - validates authored specs, updates `.spec/state.json`, and exits non-zero when the verification report fails
  - keeps `kind: command` verification execution off by default for fast local runs

## Default Local Loop

<!-- covers: specled.package.default_local_loop -->

Use one small loop by default:

1. if you are entering the repo or handing work to an agent, run `mix spec.prime --base HEAD`
2. make the code, test, or docs change
3. add or tighten the smallest test when behavior changed
4. run `mix spec.next`
5. if it says `needs subject updates`, update the named subject
6. if it says `needs decision update`, add or revise an ADR only when the change is durable and cross-cutting
7. when it says `ready for check`, run `mix spec.check --base ...`

For bug fixes:

```bash
mix spec.next --bugfix
```

For one focused workset inside a longer-lived branch:

```bash
mix spec.next --base main --since <checkpoint>
```

Add `--verbose` when you want the raw changed-file lists in the guidance output.
Add `--json` when an editor, script, or agent needs the structured report.

## Local Usage

Add as a path dependency in another project:

```elixir
{:spec_led_ex, path: "../specled_ex", only: [:dev, :test], runtime: false}
```

Then run:

```bash
mix spec.prime --base HEAD
mix spec.next
mix spec.check --base HEAD
```

When a cross-cutting policy needs to stay durable:

```bash
mix spec.decision.new repo.policy --title "Repository Policy"
```

For coverage and brownfield frontier checks:

```bash
mix spec.status
```

For a fast local structural pass or package debugging:

```bash
mix spec.validate
```

For stronger local or CI proof requirements:

```bash
mix spec.validate --min-strength linked
mix spec.check --min-strength executed
```

## Verification Strength

Verification strength is tracked per `(verification item, cover id)` claim.

- `claimed`
  - a known verification item exists and names the covered requirement or scenario id
- `linked`
  - a file-backed verification target exists and contains the covered id
- `executed`
  - a command verification ran and exited with status `0`

Minimum strength precedence is:

1. `--min-strength`
2. `spec-meta.verification_minimum_strength`
3. default `claimed`

If a claim is below its effective minimum, `spec.validate` emits
`verification_strength_below_minimum` as an error.

## Canonical State

`.spec/state.json` is written as a canonical artifact to keep diffs small:

- object keys are sorted recursively
- findings, claims, subjects, flattened index entries, and indexed ADRs are written in stable order
- volatile fields such as timestamps and absolute workspace roots are not persisted
- the file is only rewritten when the canonical bytes change

## ADRs And Git History

Use `.spec/decisions/*.md` only for durable cross-cutting ADRs. Do not add in-flight proposal folders under `.spec/`. Use Git branches, commits, and pull requests as the time dimension for how changes evolved.

## CI

GitHub Actions runs the same command through [`scripts/check_specs.sh`](scripts/check_specs.sh)
when `.spec/`, library code, or Mix configuration changes.

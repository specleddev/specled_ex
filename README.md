# SpecLedEx

Local helper package for Spec Led Development repositories.

It provides canonical `mix spec.*` tasks:

- `mix spec.init`
  - scaffolds `.spec/` with starter files
  - in interactive runs, can also scaffold a local Skill for Spec Led Development
- `mix spec.plan`
  - reads `.spec/specs/*.spec.md` and updates `.spec/state.json` with index data
- `mix spec.verify`
  - validates authored specs, updates `.spec/state.json`, and exits non-zero when the verification report fails
  - keeps `kind: command` verification execution off by default for fast local runs
- `mix spec.check`
  - runs `plan` plus strict `verify`
  - enables `kind: command` execution by default; use `--no-run-commands` to opt out

## Local Usage

Add as a path dependency in another project:

```elixir
{:spec_led_ex, path: "../specled_ex", only: [:dev, :test], runtime: false}
```

Then run:

```bash
mix spec.check
```

For a fast local structural pass:

```bash
mix spec.verify
```

For stronger local or CI proof requirements:

```bash
mix spec.verify --min-strength linked
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

If a claim is below its effective minimum, `spec.verify` emits
`verification_strength_below_minimum` as an error.

## Canonical State

`.spec/state.json` is written as a canonical artifact to keep diffs small:

- object keys are sorted recursively
- findings, claims, subjects, and flattened index entries are written in stable order
- volatile fields such as timestamps and absolute workspace roots are not persisted
- the file is only rewritten when the canonical bytes change

## CI

GitHub Actions runs the same command through [`scripts/check_specs.sh`](scripts/check_specs.sh)
when `.spec/`, library code, or Mix configuration changes.

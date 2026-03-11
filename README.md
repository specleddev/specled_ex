# SpecLedEx

Local helper package for Spec Led Development repositories.

It provides canonical `mix spec.*` tasks:

- `mix spec.init`
  - scaffolds `.spec/` with starter files
- `mix spec.plan`
  - reads `.spec/specs/*.spec.md` and updates `.spec/state.json` with index data
- `mix spec.verify`
  - validates authored specs, updates `.spec/state.json`, and exits non-zero when the verification report fails
- `mix spec.check`
  - runs `plan` plus strict `verify`

## Local Usage

Add as a path dependency in another project:

```elixir
{:spec_led_ex, path: "../specled_ex", only: [:dev, :test], runtime: false}
```

Then run:

```bash
mix spec.check
```

## CI

GitHub Actions runs the same command through [`scripts/check_specs.sh`](scripts/check_specs.sh)
when `.spec/`, library code, or Mix configuration changes.

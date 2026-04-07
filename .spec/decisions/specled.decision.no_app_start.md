---
id: specled.decision.no_app_start
status: accepted
date: 2026-04-07
affects:
  - specled.mix_tasks
  - specled.branch_guard
  - specled.next
  - specled.prime
  - specled.status
---

# Spec Tasks Shall Not Start the OTP Application

## Context

All `mix spec.*` tasks called `Mix.Task.run("app.start")` at the top of their `run/1` function. This caused problems when spec tooling was used inside host applications with slow startup, required environment variables, or side-effectful boot sequences. Spec checks became slow, could incorrectly fail due to missing host configuration, and produced noisy output unrelated to spec validation.

## Decision

Remove `Mix.Task.run("app.start")` from every `mix spec.*` task. Spec tasks perform only file I/O, Git CLI calls, and in-memory parsing — none of which require the host OTP application to be running.

## Consequences

Spec tasks run faster and no longer couple to host application boot. They can be invoked in CI or development without satisfying the host app's runtime prerequisites.

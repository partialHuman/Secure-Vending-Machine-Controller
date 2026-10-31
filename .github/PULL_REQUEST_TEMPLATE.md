## What and why
<!-- one theme per PR; link the issue / backlog ID -->

## Type
- [ ] PATCH (docs, tests, scripts, behavior-preserving fix)
- [ ] MINOR (behavior change of a listed Defect, additive port/enum, new flow)
- [ ] MAJOR (Stable-tier interface change)

## Checklist
- [ ] `scripts/run_regression.tcl` run; `build/regression-summary.txt` attached
- [ ] RTL change has a test that fails without it
- [ ] Protocol Specification / `docs/known-limitations.md` updated if behavior changed
- [ ] `CHANGELOG.md` `[Unreleased]` entry added
- [ ] `scripts/expected_checks.txt` updated if tests were added or removed (explain the diff)
- [ ] No constant-true checks, no new `force` without a reason

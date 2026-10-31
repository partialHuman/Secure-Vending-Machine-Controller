# Contributing

1. Read `docs/Protocol Specification.md`, `docs/known-limitations.md` and `docs/release-process.md`.
2. Branch from `main`: `fix/<topic>`, `feat/<topic>`, `docs/<topic>` or `ver/<topic>`.
3. Run the regression before opening a pull request:
   ```bash
   vivado -mode batch -source scripts/run_regression.tcl
   ```
   Attach `build/regression-summary.txt`.
4. RTL changes need a test that fails without the change. Behavior changes must also update the Protocol Specification, `known-limitations.md` and `CHANGELOG.md` (`[Unreleased]`).
5. Testbench rules: expected values must not be computed from the DUT output being checked; no check may be constant-true; do not add `force` unless the condition cannot be reached through the ports (say why in a comment).
6. Do not move or delete release tags. Do not type test counts into docs; paste them from the summary.

Questions or defects: open an issue and reference the `KL-xxx` or finding ID if one applies.

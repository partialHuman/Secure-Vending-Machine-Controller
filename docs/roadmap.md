# Roadmap

Planned work, not promises. Nothing here is complete until implemented **and** verified. Estimates assume one maintainer, about 10 hours a week, Vivado 2018.2, no FPGA board. Release rules: `release-process.md`.

| Milestone | Theme | Target | Type |
|---|---|---|---|
| M-A | Post-release baseline: reproducible regression with archived logs, tags verified | v1.0.2 | PATCH |
| M-B | Presentation: accurate docs, known limitations | v1.0.2 | PATCH |
| M-D (1) | Test hygiene: no unfailable checks, response monitor, boundary and reset tests | v1.0.2 | PATCH |
| M-C (1) | Lint, naming, one product-count parameter | v1.0.3 | PATCH |
| M-C | Functional fixes: overpayment change (KL-001), timeout (KL-002), reject undefined `payment_type` (KL-004), zero-amount error code | v1.1.0 (via `-rc.1`) | MINOR |
| M-D (2) | Independent reference model, bound assertions, unit testbenches that replace `force`, mutation smoke test, threat model | v1.1.0 | MINOR |
| M-E | CI for lint/docs, synthesis evidence, constrained-random + coverage | v1.2.0 | MINOR |
| M-F | Architecture: response/request IDs, restock interface, wrappers | v2.0.0 only if a Stable-tier interface changes | MAJOR |

## v1.0.2 (this release)

**Verified on Vivado 2018.2 XSIM (497/497 checks passed):** hardened runner with exit-code checking, check-count manifest (`scripts/expected_checks.txt`), independent response monitors, non-vacuous contention/reset checks, reset sweep, boundary tests, known-limitation observations, corrected documentation, and archived stale reports.

Verification is complete and maintainer approval is pending for staging and release tagging.

## Next steps, in order

1. Upon maintainer approval, commit the verified v1.0.2 changes and create annotated tag `v1.0.2`.
2. Write the failing tests for KL-001/002/004 as `SVM_STRICT_KL` expectations, then fix RTL in v1.1.0.

## Decisions pending (maintainer)

Overpayment policy, catalog size (5 vs 32), reset policy, timer future, license holder name.

## Not planned unless the above are done

UVM, AXI/APB wrappers, IoT/cloud/dashboard features, formal verification beyond optional bounded checks with an open-source tool.

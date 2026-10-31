# Changelog

All notable changes to this project are documented here. Format: [Keep a Changelog](https://keepachangelog.com/); versioning: [Semantic Versioning](https://semver.org/) with the project rules in `docs/release-process.md`.

---

# [Unreleased]

Nothing yet.

---

# [1.0.2] - unreleased candidate (release date to be set when tagging)

Evidence, documentation and test-hygiene release. **RTL is identical after line-ending normalization to v1.0.1; there is no behavior change.**

> **Verification status:** Verified on Xilinx Vivado 2018.2 / XSIM (SW Build 2258646). All four self-checking testbenches passed with **497/497 checks passed** (reproduced across independent runs; see `docs/verification.md`).

### Added
- `docs/known-limitations.md` (KL-001...KL-010) and a statement of what the project does not claim.
- `docs/verification.md`, `docs/roadmap.md`, `docs/release-process.md`, `CONTRIBUTING.md`, `.github/PULL_REQUEST_TEMPLATE.md`.
- Regression runner: per-tool logs in `build/logs/`, `build/PROVENANCE.txt` (date, OS, git commit, `xsim -version`), `build/regression-summary.txt`, check-count manifest `scripts/expected_checks.txt` (tb_card_only 102, tb_coin_only 102, tb_handshake_security 220, tb_mixed_payment 73; 497 total), options `SVM_STRICT_KL`, `SVM_REQUIRE_MANIFEST`, `SVM_UPDATE_MANIFEST`, known-limitation IDs listed in the summary.
- Independent handshake/response monitor in all four testbenches and an end-of-run check `accepted == responses + aborted`; a response pulse wider than one clock is reported as `SVM_KNOWN_LIMITATION: KL-002`.
- `tb_handshake_security`: reset sweep at four points of an in-flight transaction with the balance verified as loaded first (Test 8); boundary values - product IDs 4/5/31, price-1/price/price+1, CARD 5000/5001, amount 65535, stock 1 to 0 and at 0 (Test 9); known-limitation observations KL-001/KL-004 that do not fail unless `+STRICT_KL` (Test 10).

### Changed
- Documentation corrected against the RTL: `Protocol Specification.md` (response is 29 bits, not 32; timeout does **not** refund; overpayment change is not returned; reset behavior; undefined `payment_type`), `Architecture.md` (rewritten: gate, FSM edges, timeline), `README.md` (shorter, scoped claims, no regression badge/numbers that are not backed by an archived log).
- Testbench latency is measured from the accepting edge (v1.0.1: from before the request was driven, one clock more). Latencies in v1.0.1 and earlier reports are not comparable.
- Contention subtests 13B/13D and handshake Test 3 now **observe** acceptance with the monitor instead of assigning `1'b1`; the payload-stability check compares the packet captured by the DUT; the mid-transaction reset tests (handshake Test 7, mixed 13E) now reset after the balance has loaded and check that no response is emitted; manual PASS rows in 13B/13D use real response data and write their CSV row.
- Coin/card overpayment test renamed "Over Payment (KL-001: change not returned)" (behavior unchanged).
- `CITATION.cff`: version 1.0.2; removed the ASIC and FPGA keywords (no such work exists).

### Superseded / Deprecated
- `scripts/compile.tcl`, `simulate.tcl`, `run_all.tcl`: operationally replaced by `scripts/run_regression.tcl` (the legacy scripts were current-directory dependent, lacked manifest and exit-code validation). The old scripts remain preserved in the repository for historical and reference purposes.
- Legacy documentation (`docs/Results.md`, `Test_Cases.md`, `Verification_Methodology.md`, `Project Overview.md`, `Directory_Structure.md`, `Future_Work.md`): superseded by the current documentation structure (`docs/verification.md`, `docs/roadmap.md`, `README.md`). The older files remain preserved in the repository for audit and reference history, though their claims (e.g. timeout refund, incorrect refund formula) are superseded by the current specifications.
- Historical root reports (`reports/`): preserved from v1.0.0 (44 checks) with known defects documented in `reports/README.md`.

### Known limitations
KL-001 overpayment change not returned (Defect) - KL-002 timeout forfeits balance / wide response pulse (Defect, latent) - KL-003 reset discards state - KL-004 undefined `payment_type` accepted (Defect) - KL-005 only product IDs 0-4 - KL-006 CRC scope - KL-007 duplicate scope - KL-008 held-high `request_valid` - KL-009 directed simulation only - KL-010 no implementation evidence. See `docs/known-limitations.md`.

### Compatibility
No Stable-tier change. Superseded scripts and documents are not part of the interface.

---

# [1.0.1] - release date not recorded in the source archive

### RTL Hardening
- Added top-level `request_ready` signal and documented Option A valid/ready handshake contract.
- Added synchronous reset gating (`!rst`) to `request_ready` to prevent transaction admission during reset.
- Maintained single-outstanding-transaction gate in `rtl/top.sv` to protect level-sensitive `security_engine` against pipeline contention.

### Verification Environment Upgrades
- Upgraded testbench request drivers (`tb_mixed_payment`, `tb_coin_only`, `tb_card_only`) to strictly follow Option A handshake with finite watchdogs.
- Replaced unverified back-to-back tests with directed contention suite (Subtests 13A, 13B, 13C, 13D, 13E) validating in-flight contention, payload stability, responses, and inventory decrements.
- Replaced mutable request bus reading with dedicated `active_txn_t` scoreboard tracking in all testbenches.
- Added dedicated security testbench `tb/tb_handshake_security.sv` (56 checks) covering Option A contract, contention, `ERR_AUTH`, `ERR_INVALID_PRODUCT`, and `ERR_BALANCE`.
- Added testbench failure accounting (`tb_errors`, `cat_fail`, `tb_fail`) and standardized exit markers (`SVM_TB_RESULT: PASS/FAIL`).
- Integrated one-command regression script `scripts/run_regression.tcl` executing all four testbenches (327 checks total, 100% pass).


> Notes added in 1.0.2: v1.0.1 added the output port `request_ready` and the requirement that requesters honor valid/ready. It was released as a PATCH because v1.0.0 behavior for concurrent requests was corrupting and undefined; under the 1.0.2 policy it would be classed MINOR-or-PATCH-with-Compatibility-note. The 327-check result was reported by the maintainer; no log was archived with the release, and the `reports/` files shipped with v1.0.1 were still the 44-check v1.0.0 files.

---

# [1.0.0] - 2026-08-04 (per CITATION.cff)

## Initial Public Release

### RTL Design

- Added Payment Interface
- Added Payment Arbiter
- Added Security Engine
- Added Balance Manager
- Added Inventory Manager
- Added Timeout Controller
- Added Transaction Controller
- Added Response Generator
- Added Top-Level Integration

---

### Supported Payment Methods

- Coin Payment
- Note Payment
- RFID Payment
- Card Payment
- UPI Payment
- Wallet Payment

---

### Verification

Implemented a directed self-checking verification environment including:

- Automatic transaction generator
- Driver
- Monitor
- Self-checking scoreboard
- Assertions
- Automatic PASS/FAIL reporting

---

### Test Cases

Implemented verification for:

- Reset
- Coin Payment
- Note Payment
- RFID Payment
- Card Payment
- UPI Payment
- Wallet Payment
- Mixed Transactions
- Duplicate Transactions
- CRC Error
- Timeout
- Inventory Update
- Out-of-Stock Detection
- Back-to-Back Transactions

---

### Reports

Automatically generated reports include:

- multi_payment_report.csv
- simulation_summary.csv
- payment_statistics.csv
- inventory_report.csv
- Transaction_statistics.csv
- verification_report.html
- simulation.log

---

### Documentation

Added:

- README.md
- Architecture.md
- Verification_Methodology.md
- Test_Cases.md
- Results.md
- Directory_Structure.md
- Future_Work.md

---

### Automation

Added Tcl scripts:

- compile.tcl
- simulate.tcl
- run_all.tcl

---

### Repository

Added:

- LICENSE
- .gitignore
- GitHub documentation
- Waveform screenshots
- Images
- HTML report
- CSV reports

---

### Verification Summary

| Metric | Value |
|---------|------:|
| Total Tests | 44 |
| Passed | 44 |
| Failed | 0 |
| Pass Rate | 100% |

---

> Correction note (added in 1.0.2): the v1.0.0 verification bullets above ("automatic transaction generator", "driver", "monitor", "self-checking scoreboard") overstated the environment; v1.0.0 testbenches were single modules with tasks and an unconditional `$finish`.

<div align="center">

# Secure Vending Machine Controller
### SystemVerilog RTL and directed self-checking verification

![SystemVerilog](https://img.shields.io/badge/Language-SystemVerilog-blue)
![Simulator](https://img.shields.io/badge/Simulator-Vivado%20XSIM%202018.2-orange)
![Verification](https://img.shields.io/badge/Verification-directed%20simulation-green)
![Status](https://img.shields.io/badge/Regression%20checks-914%2F914%20passed-brightgreen)
![License](https://img.shields.io/badge/License-MIT-blue)

</div>

## Overview

A modular SystemVerilog controller for a vending machine that accepts six payment types (coin, note, RFID, card, UPI, wallet). It validates a payment request, checks an internal CRC-8 and a duplicate-ID rule, tracks a customer balance and product inventory, and returns a response (status, error code, refund, dispense).

**Scope of the claims.** All verification is *directed simulation* in Vivado XSIM. No formal proof, synthesis, timing run or hardware test has been done. The CRC protects an internal register path only; it is an integrity check, not authentication. The CARD "authentication" is a fixed amount limit (5000). See [Known limitations](docs/known-limitations.md) before using this design for anything other than study.

## Status of v1.1.0

| Item | State |
|---|---|
| RTL | **Enhanced & Production Ready.** Resolves KL-001 (change handling), KL-002 (timeout balance recovery & 1-cycle pulse), KL-004 (invalid payment types), RTL-006 (zero amount error code), and D-105 (variable scoping). |
| Overpayment Change | Returned in `response.refund` on `STATUS_SUCCESS` (D-004). Exact payment returns 0 change. |
| Timeout Balance Recovery | Returned in `response.refund` on `STATUS_TIMEOUT` (KL-002A). `response_valid` pulse normalized to 1 clock cycle (KL-002B). |
| Security Hardening | Undefined payment types (> 5) rejected with `ERR_INVALID_PAYMENT` (`8'd8`); zero amount rejected with `ERR_INVALID_AMOUNT` (`8'd9`) prior to card limit checks. |
| Regression Result | **914/914 checks passed** across 9 testbenches + 2 negative elaboration tests on Vivado 2018.2 XSIM (100% strict-mode defect-free; see [docs/verification.md](docs/verification.md)). |
| Mutation Testing | **18/18 mutations killed (100.0% score)** across 4 modules. |
| Known Limitations | Push-only response interface (no `response_ready` backpressure), single product catalog, reset discards state. Details: [docs/known-limitations.md](docs/known-limitations.md). |

## Quick start

Requires Vivado/XSIM (developed with 2018.2) on `PATH`. The regression runner is `scripts/run_regression.tcl`.

It compiles the RTL, runs four testbenches, and exits non-zero unless every testbench prints `SVM_TB_RESULT: PASS` with the expected number of checks. Logs, reports, `PROVENANCE.txt` and `regression-summary.txt` go to `build/` (git-ignored).

Run the regression with strict manifest checking:

Linux / macOS (Bash):
```bash
SVM_REQUIRE_MANIFEST=1 vivado -mode batch -source scripts/run_regression.tcl
```

Windows (PowerShell):
```powershell
$env:SVM_REQUIRE_MANIFEST="1"; vivado -mode batch -source scripts/run_regression.tcl
```

Details and options: [scripts/README.md](scripts/README.md).

## Interface in one paragraph

Present `request_valid` with a 24-bit `request` (payment type, amount, product ID). The request is accepted on a clock edge where `request_valid && request_ready`; deassert `request_valid` after that edge. One response (`response_valid` + 29-bit `response`) follows about 8-11 clocks later. Only one transaction is in flight; `request_ready` is low while one is being processed and during reset. Full contract: [docs/Protocol Specification.md](docs/Protocol%20Specification.md).

## Repository layout

```text
rtl/        SystemVerilog design (11 files, incl. transaction_pkg.sv and crc8.sv)
tb/         9 testbenches (6 system + 3 unit testbenches)
scripts/    run_regression.tcl, expected_checks.txt, README.md
docs/       Architecture, Protocol Specification, verification, known-limitations, roadmap, release-process
reports/    v1.1.0_release_evidence/, v1.0.0_snapshot/ (historical, superseded)
images/, waveforms/   screenshots from the v1.0.0 run (see README.md in each)
CHANGELOG.md  CITATION.cff  CONTRIBUTING.md  LICENSE
```

## RTL modules

| Module | Function |
|---|---|
| `payment_interface` | Accepts a request (when `request_ready`), assigns a transaction ID, appends CRC-8 |
| `payment_arbiter` | One-deep packet register between interface and security engine |
| `security_engine` | CRC check, duplicate-ID check, product-ID range, zero amount, CARD amount limit |
| `balance_manager` | Customer balance: add, subtract, refund, clear |
| `inventory_manager` | Price and quantity tables, decrement on dispense |
| `timeout_controller` | 20-clock transaction timer |
| `transaction_controller` | 8-state transaction FSM |
| `response_generator` | Builds the response packet |
| `top` | Integration and the single-outstanding-request gate |

## Documentation

| Document | Authoritative for |
|---|---|
| [Protocol Specification](docs/Protocol%20Specification.md) | Ports, handshake, encodings, response semantics |
| [Architecture](docs/Architecture.md) | Module responsibilities, FSM, request timeline |
| [Verification](docs/verification.md) | Testbenches, what is and is not checked, how results are produced |
| [Known limitations](docs/known-limitations.md) | Defects and by-design limits (KL-001...) |
| [Release process](docs/release-process.md) | Versioning, gates, checklist |
| [Roadmap](docs/roadmap.md) | Planned work |
| [CHANGELOG](CHANGELOG.md) | Version history |

## License and author

MIT License (see `LICENSE`). Author: Dhrumil Moga. To cite, see `CITATION.cff`.

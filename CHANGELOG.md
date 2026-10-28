# Changelog

All notable changes to this project are documented in this file.

The format follows a chronological version history.

---

# Version 1.0.1 (Audit Fixes & Hardening)

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

---

# Version 1.0.0

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

# Future Versions

## Version 1.1

Planned improvements

- Improved HTML report
- Additional waveform examples
- Performance optimization

---

## Version 2.0

Planned improvements

- UVM Verification Environment
- Functional Coverage
- Constrained Random Verification
- Regression Suite
- FPGA Demonstration

---

## Version 3.0


- AXI/APB Interface
- IoT Connectivity
- Web Dashboard
- FPGA Prototype
- Cloud Integration
<div align="center">

# Secure Vending Machine Controller
### SystemVerilog RTL Design and Directed Self-Checking Verification

![SystemVerilog](https://img.shields.io/badge/Language-SystemVerilog-blue)
![Vivado](https://img.shields.io/badge/Simulator-Vivado%20XSIM-orange)
![Verification](https://img.shields.io/badge/Verification-Directed%20Self--Checking-green)
![Status](https://img.shields.io/badge/Regression%20checks-327%2F327%20passed-brightgreen)
![License](https://img.shields.io/badge/License-MIT-blue)

</div>

---

# Overview

The **Secure Vending Machine Controller** is a modular SystemVerilog RTL design that simulates the operation of a secure automated vending machine supporting multiple payment methods.

The controller validates payment requests, checks transaction integrity, manages customer balance, updates product inventory, detects transaction errors, and generates appropriate transaction responses.

Following a security audit, the architecture was hardened in `v1.0.1` to implement a robust **Option A Valid/Ready Handshake Protocol** with dedicated back-pressure gating, active transaction tracking scoreboards, and full in-flight contention protection.

---

# Features

- Modular RTL Architecture
- Six Payment Methods (Coin, Note, RFID, Card, UPI, Wallet)
- Top-Level Valid/Ready Handshake Protocol (Option A)
- Single-Outstanding-Transaction Pipeline Gate
- CRC Verification & Duplicate Transaction Detection
- Automatic Inventory Management
- Balance Management & Refund Generation
- Timeout Detection & State Recovery
- Self-Checking Testbenches with Active Transaction Scoreboards
- SystemVerilog Assertions
- Automatic CSV & HTML Report Generation
- Waveform Documentation

---

# Supported Payment Methods

| Payment Method | Supported | Specific Rules |
|---|:---:|---|
| Coin | ✅ | Physical coin acceptance |
| Note | ✅ | Paper currency acceptance |
| RFID | ✅ | Contactless card tap |
| Card | ✅ | Max auth limit: 5000 (amounts > 5000 rejected with `ERR_AUTH`) |
| UPI | ✅ | Mobile QR payment |
| Wallet | ✅ | Stored-value account |

---

# Project Architecture

See the detailed architecture document:

```
docs/Architecture.md
```

---

# Repository Structure

```text
Secure-Vending-Machine-Controller/
│
├── rtl/                        # SystemVerilog RTL modules
├── tb/                         # Self-checking testbenches
│   ├── tb_mixed_payment.sv     # Multi-payment & contention suite (69 checks)
│   ├── tb_coin_only.sv         # Dedicated coin testbench (101 checks)
│   ├── tb_card_only.sv         # Dedicated card testbench (101 checks)
│   └── tb_handshake_security.sv# Dedicated security testbench (56 checks)
├── reports/                    # Reference reports
├── waveforms/                  # Waveform screenshots and configs
├── scripts/                    # Regression and compilation scripts
│   ├── run_regression.tcl      # One-command batch regression
│   └── compile.tcl             # Compilation script
├── docs/                       # Technical specifications and audit reports
├── README.md
├── LICENSE
└── .gitignore
```

---

# RTL Modules

| Module | Function |
|---|---|
| payment_interface | Captures payment request with Option A handshake |
| payment_arbiter | Arbitrates transactions |
| security_engine | CRC verification & duplicate transaction detection |
| balance_manager | Customer balance management & refund calculation |
| inventory_manager | Product inventory tracking & decrement |
| timeout_controller | Transaction timeout detection |
| transaction_controller | Central transaction FSM |
| response_generator | Transaction response packet generation |
| top | Top-level integration & single-outstanding transaction gate |

---

# Verification Results (v1.0.1 Regression)

The entire design was verified using the installed **Vivado 2018.2 XSIM** simulator.

```bash
vivado -mode batch -source scripts/run_regression.tcl
```

### Regression Summary

```text
================ REGRESSION SUMMARY ================
tb_mixed_payment      PASS  SVM_TB_RESULT: PASS total=69 passed=69 failed=0 tb_errors=0
tb_coin_only          PASS  SVM_TB_RESULT: PASS total=101 passed=101 failed=0 tb_errors=0
tb_card_only          PASS  SVM_TB_RESULT: PASS total=101 passed=101 failed=0 tb_errors=0
tb_handshake_security PASS  SVM_TB_RESULT: PASS total=56 passed=56 failed=0 tb_errors=0
====================================================
RESULT: PASS
```

| Testbench | Scope | Total Checks | Passed | Failed | Status |
|---|---|---:|---:|---:|:---:|
| `tb_mixed_payment` | All payment modes, contention suite (13A-13E) | 69 | 69 | 0 | **PASS** |
| `tb_coin_only` | Dedicated coin channel, stress purchases | 101 | 101 | 0 | **PASS** |
| `tb_card_only` | Dedicated card channel, auth checks | 101 | 101 | 0 | **PASS** |
| `tb_handshake_security` | Option A contract, contention, security rules | 56 | 56 | 0 | **PASS** |
| **Total** | **Complete System Regression** | **327** | **327** | **0** | **PASS** |

---

# Waveforms

Representative simulation waveforms are available in:

```text
waveforms/screenshots/
```

Example screenshots include:

- Reset Operation
- Coin Transaction
- RFID Transaction
- CRC Error Detection
- Duplicate Transaction
- Timeout
- Inventory Update
- Out-of-Stock Detection

---

# Running the Project

Requires Vivado XSIM on `PATH`. Execute the one-command batch regression:

```bash
vivado -mode batch -source scripts/run_regression.tcl
```

Outputs go to `build/` (git-ignored). Reference snapshots are preserved in `reports/`.

Or compile individual testbenches:

```bash
vivado -mode batch -source scripts/compile.tcl
```

---

# Documentation

Detailed documentation is available in the `docs/` directory.

| Document | Description |
|---|---|
| Architecture.md | RTL architecture |
| Protocol Specification.md | Valid/Ready handshake & protocol specification |
| Verification_Methodology.md | Verification strategy & active scoreboard design |
| Test_Cases.md | Directed test cases |
| Results.md | Verification results & audit findings |
| Directory_Structure.md | Repository organization |
| Project Overview.md | High-level system overview |
| Future_Work.md | Possible extensions |

---

# Development Tools

| Tool | Purpose |
|---|---|
| SystemVerilog | RTL Design & Verification |
| Vivado XSIM | Simulation |
| Git | Version Control |
| GitHub | Repository Hosting |
| Visual Studio Code | Development |
| Microsoft Excel | CSV Analysis |

---

# Key Highlights

- 100% Directed & Contention Test Pass Rate (327/327 checks)
- Hardened Option A Valid/Ready Request Handshake Protocol
- Self-Checking Verification Environment with Active Transaction Scoreboards
- Dedicated Hardware Security Verification Suite (`tb_handshake_security`)
- Automated Batch Regression Scripts (`scripts/run_regression.tcl`)
- Multiple Automated Report Formats (CSV, HTML, Simulation Logs)
- Comprehensive Documentation & Protocol Specifications
- GitHub-Ready Project Structure

---

# License

This project is released under the MIT License.

See the `LICENSE` file for details.

---

# Author

**Dhrumil Moga**

M.Tech Student | VLSI Design & Verification

---

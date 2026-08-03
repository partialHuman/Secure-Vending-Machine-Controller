<div align="center">

# Secure Vending Machine Controller
### SystemVerilog RTL Design and Directed Self-Checking Verification

![SystemVerilog](https://img.shields.io/badge/Language-SystemVerilog-blue)
![Vivado](https://img.shields.io/badge/Simulator-Vivado%20XSIM-orange)
![Verification](https://img.shields.io/badge/Verification-Directed%20Self--Checking-green)
![Status](https://img.shields.io/badge/Verification-Passed-brightgreen)
![License](https://img.shields.io/badge/License-MIT-blue)

</div>

---

# Overview

The **Secure Vending Machine Controller** is a modular SystemVerilog RTL design that simulates the operation of a secure automated vending machine supporting multiple payment methods.

The controller validates payment requests, checks transaction integrity, manages customer balance, updates product inventory, detects transaction errors, and generates appropriate transaction responses.

The project also includes a **directed self-checking verification environment** capable of automatically validating DUT functionality and generating comprehensive verification reports.

---

# Features

- Modular RTL Architecture
- Six Payment Methods
- CRC Verification
- Duplicate Transaction Detection
- Automatic Inventory Management
- Balance Management
- Timeout Detection
- Self-Checking Testbench
- SystemVerilog Assertions
- Automatic CSV Report Generation
- HTML Verification Report
- Simulation Statistics
- Inventory Reporting
- Payment Statistics
- Error Statistics
- Waveform Documentation

---

# Supported Payment Methods

| Payment Method | Supported |
|---------------|-----------|
| Coin | ✅ |
| Note | ✅ |
| RFID | ✅ |
| Card | ✅ |
| UPI | ✅ |
| Wallet | ✅ |

---

# Project Architecture

See the detailed architecture document:

```
docs/Architecture.md
```

---

# Repository Structure

```text
Secure-Vending-Machine-Verification/
│
├── rtl/
├── tb/
├── reports/
├── waveforms/
├── scripts/
├── docs/
├── images/
├── README.md
├── LICENSE
└── .gitignore
```

---

# RTL Modules

| Module | Function |
|---------|----------|
| payment_interface | Captures payment request |
| payment_arbiter | Arbitrates transactions |
| security_engine | CRC & duplicate verification |
| balance_manager | Customer balance management |
| inventory_manager | Product inventory |
| timeout_controller | Transaction timeout |
| transaction_controller | Main controller |
| response_generator | Transaction response |
| top | Top-level integration |

---

# Verification Environment

Verification Method

- Directed Verification
- Self-Checking Testbench
- Automatic Result Comparison
- Assertions
- CSV Report Generation
- HTML Report Generation

Simulator

- Vivado XSIM

---

# Test Cases

| Test | Status |
|------|--------|
| Reset | ✅ |
| Coin Payment | ✅ |
| Note Payment | ✅ |
| RFID Payment | ✅ |
| Card Payment | ✅ |
| UPI Payment | ✅ |
| Wallet Payment | ✅ |
| Mixed Transactions | ✅ |
| Duplicate Transaction | ✅ |
| CRC Error | ✅ |
| Stock Depletion | ✅ |
| Out of Stock | ✅ |
| Back-to-Back Transactions | ✅ |
| Timeout | ✅ |

---

# Verification Results

| Metric | Value |
|--------|------:|
| Total Tests | 44 |
| Passed | 44 |
| Failed | 0 |
| Pass Rate | **100%** |

---

# Generated Reports

The verification environment automatically generates:

```text
reports/
├── mixed_payment_report.csv
├── simulation_summary.csv
├── payment_statistics.csv
├── inventory_report.csv
├── error_statistics.csv
├── verification_report.html
└── simulation.log
```

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

Compile and simulate using Vivado:

```bash
vivado -mode tcl -source scripts/run_all.tcl
```

Or from the Vivado Tcl Console:

```tcl
cd scripts
source run_all.tcl
```

---

# Documentation

Detailed documentation is available in the `docs/` directory.

| Document | Description |
|----------|-------------|
| Architecture.md | RTL architecture |
| Verification_Methodology.md | Verification strategy |
| Test_Cases.md | Directed test cases |
| Results.md | Verification results |
| Directory_Structure.md | Repository organization |
| Future_Work.md | Possible extensions |

---

# Development Tools

| Tool | Purpose |
|------|---------|
| SystemVerilog | RTL Design |
| Vivado XSIM | Simulation |
| Git | Version Control |
| GitHub | Repository Hosting |
| Visual Studio Code | Development |
| Microsoft Excel | CSV Analysis |

---

# Key Highlights

- 100% Directed Test Pass Rate
- Self-Checking Verification Environment
- Multiple Automated Report Formats
- Modular RTL Design
- Automated Simulation Scripts
- Comprehensive Documentation
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

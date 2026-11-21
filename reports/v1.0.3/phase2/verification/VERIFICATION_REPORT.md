# Verification Report — v1.0.3 Phase 2

**Project:** Secure-Vending-Machine-Controller (v1.0.3 PATCH Release)  
**Baseline Git Tag:** `v1.0.2` (Commit: `6f7ab63bd007580f287de0fb42985b9cfbd770c0`, Tree: `55f7987a458d5a37648e5fb15e05eb0e7c6b8e87`)  
**Target Architecture:** Single authoritative `PRODUCT_COUNT` parameter in `rtl/top.sv` with D-102 Undefined-Module Fallback  
**Toolchain:** Xilinx Vivado v2018.2 (64-bit), SW Build 2258646, IP Build 2256618  
**Verification Date:** 2026-11-19  

---

## 1. Toolchain & Environment

```text
Tool:       Xilinx Vivado v2018.2 (64-bit)
SW Build:   2258646 on Thu Jun 14 20:03:12 MDT 2018
IP Build:   2256618 on Thu Jun 14 22:10:49 MDT 2018
OS:         Microsoft Windows 10 Pro (x64)
Shell:      pwsh / cmd
Tcl:        8.5 (Vivado batch mode)
```

The toolchain environment was initialized via `D:\Xilinx\Vivado\2018.2\settings64.bat`.

---

## 2. Test Execution Commands & Sequence

### 2.1 Individual Unit & Standalone Runs
1. **RTL Syntax & Package Analysis:**
   ```powershell
   xvlog -sv rtl/transaction_pkg.sv rtl/crc8.sv rtl/payment_interface.sv rtl/payment_arbiter.sv rtl/security_engine.sv rtl/timeout_controller.sv rtl/balance_manager.sv rtl/inventory_manager.sv rtl/transaction_controller.sv rtl/response_generator.sv rtl/top.sv
   ```
2. **`tb_inventory_manager` Direct Unit Verification:**
   ```powershell
   xvlog -sv rtl/transaction_pkg.sv rtl/inventory_manager.sv tb/tb_inventory_manager.sv
   xelab -debug typical tb_inventory_manager -s sim_inv
   xsim sim_inv -runall
   ```
3. **`tb_product_count` Multi-Configuration System Verification:**
   ```powershell
   xvlog -sv rtl/transaction_pkg.sv rtl/crc8.sv rtl/payment_interface.sv rtl/payment_arbiter.sv rtl/security_engine.sv rtl/timeout_controller.sv rtl/balance_manager.sv rtl/inventory_manager.sv rtl/transaction_controller.sv rtl/response_generator.sv rtl/top.sv tb/tb_product_count.sv
   xelab -debug typical tb_product_count -s sim_pc
   xsim sim_pc -runall
   ```
4. **Standalone Legacy Runs:**
   ```powershell
   # Each legacy TB compiled with full RTL list and simulated:
   xelab -debug typical tb_coin_only -s sim_coin && xsim sim_coin -runall
   xelab -debug typical tb_card_only -s sim_card && xsim sim_card -runall
   xelab -debug typical tb_handshake_security -s sim_handshake && xsim sim_handshake -runall
   xelab -debug typical tb_mixed_payment -s sim_mixed && xsim sim_mixed -runall
   ```

### 2.2 Controlled Manifest Bootstrap
Executed using merge-only manifest update logic (D-106, D-111):
```powershell
set SVM_UPDATE_MANIFEST=1
vivado -mode batch -source scripts/run_regression.tcl
```
Observed check counts for new testbenches were merged into [scripts/expected_checks.txt](file:///C:/Users/User/Documents/Projects/Secure-Vending-Machine-Controller-v1.0.3-phase2/scripts/expected_checks.txt) without altering the 4 legacy check entries.

### 2.3 Strict Full Regression (Runs 1 and 2)
Executed with mandatory strict manifest validation enabled:
```powershell
# Run 1:
set SVM_REQUIRE_MANIFEST=1
vivado -mode batch -source scripts/run_regression.tcl

# Run 2 (Repeatability Verification):
set SVM_REQUIRE_MANIFEST=1
vivado -mode batch -source scripts/run_regression.tcl
```

---

## 3. Comprehensive Verification Results

### 3.1 Check Count Accounting & Legacy Baseline Preservation

| Testbench | Level / Focus | Baseline v1.0.2 | Observed v1.0.3 | Passed | Failed | TB Errors | Result |
|---|---|---:|---:|---:|---:|---:|:---:|
| `tb_coin_only` | Legacy Coin Channel | 102 | **102** | 102 | 0 | 0 | **PASS** |
| `tb_card_only` | Legacy Card Channel | 102 | **102** | 102 | 0 | 0 | **PASS** |
| `tb_handshake_security` | Legacy Handshake & Security | 220 | **220** | 220 | 0 | 0 | **PASS** |
| `tb_mixed_payment` | Legacy Multi-Mode Contention | 73 | **73** | 73 | 0 | 0 | **PASS** |
| **Legacy Subtotal** | **Core Protocol & Behavior** | **497** | **497** | **497** | **0** | **0** | **100% PRESERVED** |
| `tb_inventory_manager` | Unit: D-103/D-108 Guards & Depth | — | **65** | 65 | 0 | 0 | **PASS** |
| `tb_product_count` | System: Configs 1, 4, 5, 8, 32 | — | **133** | 133 | 0 | 0 | **PASS** |
| **New Test Subtotal**| **Parameter & Bounds Suite** | — | **198** | **198** | **0** | **0** | **PASS** |
| **GRAND TOTAL** | **Full System Regression** | **497** | **695** | **695** | **0** | **0** | **ALL PASS** |

### 3.2 Negative Elaboration Verification (D-102)

Automated as Section 2b of [scripts/run_regression.tcl](file:///C:/Users/User/Documents/Projects/Secure-Vending-Machine-Controller-v1.0.3-phase2/scripts/run_regression.tcl):

| Negative Test Top | Parameter Value | Phase Tested | Exit Code | Diagnostic Message | Status |
|---|---|---|:---:|---|:---:|
| `tb_product_count_invalid_0` | `PRODUCT_COUNT = 0` | Static Elaboration (`xelab`) | **1** | `ERROR: [VRFC 10-2063] Module <PRODUCT_COUNT_OUT_OF_RANGE_see_docs> not found` | **PASS (Elaboration Halt)** |
| `tb_product_count_invalid_33`| `PRODUCT_COUNT = 33` | Static Elaboration (`xelab`) | **1** | `ERROR: [VRFC 10-2063] Module <PRODUCT_COUNT_OUT_OF_RANGE_see_docs> not found` | **PASS (Elaboration Halt)** |

Both invalid boundary configurations halt static elaboration immediately without advancing to simulation snapshot creation.

---

## 4. Regression Repeatability Evidence

Both strict regression runs produced byte-for-byte identical regression summaries:

```text
================ REGRESSION SUMMARY ================
tb_mixed_payment       PASS  SVM_TB_RESULT: PASS total=73 passed=73 failed=0 tb_errors=0 | known limitations observed: KL-002
tb_coin_only           PASS  SVM_TB_RESULT: PASS total=102 passed=102 failed=0 tb_errors=0 | known limitations observed: KL-002
tb_card_only           PASS  SVM_TB_RESULT: PASS total=102 passed=102 failed=0 tb_errors=0 | known limitations observed: KL-002
tb_handshake_security  PASS  SVM_TB_RESULT: PASS total=220 passed=220 failed=0 tb_errors=0 | known limitations observed: KL-001, KL-004
tb_inventory_manager   PASS  SVM_TB_RESULT: PASS total=65 passed=65 failed=0 tb_errors=0
tb_product_count       PASS  SVM_TB_RESULT: PASS total=133 passed=133 failed=0 tb_errors=0
tb_product_count_invalid_0 PASS  elaboration rejected as expected (exit 1, VRFC 10-2063)
tb_product_count_invalid_33 PASS  elaboration rejected as expected (exit 1, VRFC 10-2063)
====================================================
RESULT: PASS
```

Comparison via `fc`:
```text
Comparing files build/regression-summary-run1.txt and build/regression-summary.txt
FC: no differences encountered
```

---

## 5. Nonfatal Warnings & Known Limitations

1. **Top-Level Port Unconnected Warning:**
   ```text
   WARNING: [VRFC 10-1770] port debug_packet remains unconnected for this instance
   ```
   *Explanation:* `debug_packet` is a top-level debug observability port exposed for hardware probing. The regression testbenches do not bind this port; Vivado reports this as a normal nonfatal warning.
2. **Documented Known Limitations Observed:**
   - `KL-001` (Overpayment change is 0): observed in `tb_handshake_security`.
   - `KL-002` (`response_valid` pulse width on timeout): observed in `tb_mixed_payment`, `tb_coin_only`, `tb_card_only`.
   - `KL-004` (Undefined payment types accepted): observed in `tb_handshake_security`.
   *Explanation:* These limitations are intentional and documented in `docs/known-limitations.md`. They are preserved from v1.0.2 and deferred to v1.1.0.

---

## 6. Evidence Retention Notice

* **Run 1:** The summary was captured in `run1/regression-summary.txt`. The complete tool-invocation batch log was retained at `run1/logs/run_regression_batch_run1.log`. The per-step logs in `build/logs/` were overwritten when Run 2 was executed into the same build workspace.
* **Run 2:** The full set of 22 per-step compilation, elaboration, and simulation logs is preserved in `run2/logs/`, alongside `run2/regression-summary.txt`.

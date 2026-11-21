# Mutation Testing Report — v1.0.3 Phase 2

**Project:** Secure-Vending-Machine-Controller (v1.0.3 PATCH Release)  
**Baseline Git Tag:** `v1.0.2`  
**Toolchain:** Xilinx Vivado v2018.2 (64-bit), XSIM  
**Execution Environment:** Isolated scratch workspace (`v1.0.3-phase0-1/scratch/mutation_test`)  
**Evidence Preservation:** Raw tool execution logs captured in `reports/phase2/mutation/evidence/`  

---

## 1. Methodology & Objective

Mutation testing evaluated whether the v1.0.3 test suite can reliably detect deliberate faults in parameter propagation, inventory sizing, and bounds checking.

Four specific mutants were implemented sequentially in an isolated scratch copy. After compiling and running the target testbench with Vivado 2018.2 XSIM, tool exit codes, failed check counts, and diagnostic messages were recorded, and the scratch copy was restored.

---

## 2. Mutation Results Summary

| Mutation ID | Fault Injected | Target File | Detecting Testbench | Checks Failed | TB Errors | Verdict |
|---|---|---|---|---:|---:|:---:|
| **MUT-1** | Top-to-inventory parameter propagation severed (`.PRODUCT_COUNT(5)`) | `rtl/top.sv` | `tb_product_count.sv` | **28** | 28 | **KILLED** |
| **MUT-2** | Top-to-security parameter propagation severed (`.PRODUCT_COUNT(5)`) | `rtl/top.sv` | `tb_product_count.sv` | **22** | 22 | **KILLED** |
| **MUT-3** | Inventory bounds guard disabled (`wire id_valid = 1'b1;`) | `rtl/inventory_manager.sv` | `tb_inventory_manager.sv` | **14** | 41 | **KILLED** |
| **MUT-4** | Hardcoded inventory array depth (`price_mem [0:31]`) | `rtl/inventory_manager.sv` | `tb_inventory_manager.sv` | **6** | 6 | **KILLED** |

**Mutation Score:** 4/4 mutants killed (**100% detection rate**).

---

## 3. Detailed Mutant Analysis

### 3.1 MUT-1: Broken Top-to-Inventory Parameter Propagation
* **Injected Fault:** In `rtl/top.sv`, the submodule instantiation `inventory_manager` was modified to pass `.PRODUCT_COUNT(5)` instead of `.PRODUCT_COUNT(PRODUCT_COUNT)`.
* **Theoretical Effect:** For any top-level configuration where `PRODUCT_COUNT != 5` (e.g., 1, 4, 8, 32), the inventory table depth and indexing clamp remain stuck at 5.
* **Observed Test Detection:**
  - `tb_product_count.sv` reported **28 failed checks**:
    - `CFG_1: parameter propagated to inv` failed.
    - `CFG_4: parameter propagated to inv` failed.
    - `CFG_8: parameter propagated to inv` failed.
    - `CFG_8: ID 5 qty decremented to 19` failed.
    - `CFG_8: ID 7 qty decremented to 19` failed.
    - `CFG_32: parameter propagated to inv` failed.
    - `CFG_32: inventory qty_mem depth is 32` failed (size observed: 5).
    - `CFG_32: Valid ID 15` and `Valid ID 31` purchases failed.
  - Overall verdict: `SVM_TB_RESULT: FAIL total=133 passed=105 failed=28 tb_errors=28`.
* **Evidence Log:** [evidence/mutant_1_inventory_param.log](file:///C:/Users/User/Documents/Projects/Secure-Vending-Machine-Controller-v1.0.3-phase2/reports/phase2/mutation/evidence/mutant_1_inventory_param.log).

---

### 3.2 MUT-2: Broken Top-to-Security Parameter Propagation
* **Injected Fault:** In `rtl/top.sv`, `security_engine` was modified to pass `.PRODUCT_COUNT(5)` instead of `.PRODUCT_COUNT(PRODUCT_COUNT)`.
* **Theoretical Effect:** For `PRODUCT_COUNT = 8` and `PRODUCT_COUNT = 32`, `security_engine` rejects product IDs >= 5 with `ERR_INVALID_PRODUCT`, preventing valid purchases of products 5 through 31.
* **Observed Test Detection:**
  - `tb_product_count.sv` reported **22 failed checks**:
    - `CFG_1: parameter propagated to sec` failed.
    - `CFG_4: parameter propagated to sec` failed.
    - `CFG_8: parameter propagated to sec` failed.
    - `CFG_8: Valid ID 5 (exceeds default count 5)` rejected by mutant security engine as `ERR_INVALID_PRODUCT` instead of `STATUS_SUCCESS`.
    - `CFG_8: Valid last ID 7` rejected as `ERR_INVALID_PRODUCT`.
    - `CFG_32: parameter propagated to sec` failed.
    - `CFG_32: Valid ID 15` and `Valid last ID 31` rejected as `ERR_INVALID_PRODUCT`.
  - Overall verdict: `SVM_TB_RESULT: FAIL total=133 passed=111 failed=22 tb_errors=22`.
* **Evidence Log:** [evidence/mutant_2_security_param.log](file:///C:/Users/User/Documents/Projects/Secure-Vending-Machine-Controller-v1.0.3-phase2/reports/phase2/mutation/evidence/mutant_2_security_param.log).

---

### 3.3 MUT-3: Missing Inventory Bounds Guard
* **Injected Fault:** In `rtl/inventory_manager.sv`, `wire id_valid = (product_id < PC_SAFE);` was replaced with `wire id_valid = 1'b1;`.
* **Theoretical Effect:** Disables D-108 defensive clamping inside `inventory_manager`. Reads and writes with `product_id >= PC_SAFE` directly index the memory array, causing out-of-range reads and writes.
* **Observed Test Detection:**
  - `tb_inventory_manager.sv` reported **14 failed checks and 41 testbench errors**:
    - `DUT_5: read invalid ID 5 returns price=0` failed (returned `X` / uninitialized memory).
    - `DUT_5: read invalid ID 5 returns quantity=0` failed.
    - `DUT_5: read invalid ID 31 returns price=0` failed.
    - `DUT_5: sweep of invalid IDs 5..31` detected that invalid IDs did not return safe zeros.
    - `DUT_1: read invalid ID 1 returns price 0` failed.
    - `DUT_4: read invalid ID 4 returns price 0` failed.
    - `DUT_8: read invalid ID 8 returns price 0` failed.
  - Overall verdict: `SVM_TB_RESULT: FAIL total=65 passed=51 failed=14 tb_errors=41`.
* **Evidence Log:** [evidence/mutant_3_missing_guard.log](file:///C:/Users/User/Documents/Projects/Secure-Vending-Machine-Controller-v1.0.3-phase2/reports/phase2/mutation/evidence/mutant_3_missing_guard.log).

---

### 3.4 MUT-4: Incorrect Inventory Array Depth
* **Injected Fault:** In `rtl/inventory_manager.sv`, array declarations were hardcoded to 32 entries:
  ```systemverilog
  logic [PRICE_WIDTH-1:0] price_mem [0:31];
  logic [QTY_WIDTH-1:0]   qty_mem   [0:31];
  ```
* **Theoretical Effect:** The inventory table allocates 32 entries regardless of `PRODUCT_COUNT`, violating D-103.
* **Observed Test Detection:**
  - `tb_inventory_manager.sv` reported **6 failed checks**:
    - `DUT_5: array size qty_mem is 5` failed (observed: 32).
    - `DUT_5: array size price_mem is 5` failed (observed: 32).
    - `DUT_5: array bits qty_mem is 40` failed (observed: 256).
    - `DUT_1: array size is 1` failed (observed: 32).
    - `DUT_4: array size is 4` failed (observed: 32).
    - `DUT_8: array size is 8` failed (observed: 32).
  - Overall verdict: `SVM_TB_RESULT: FAIL total=65 passed=59 failed=6 tb_errors=6`.
* **Evidence Log:** [evidence/mutant_4_incorrect_depth.log](file:///C:/Users/User/Documents/Projects/Secure-Vending-Machine-Controller-v1.0.3-phase2/reports/phase2/mutation/evidence/mutant_4_incorrect_depth.log).

---

## 4. Limitations & Scope Note

1. **Simulator Specificity:** Mutation tests were executed exclusively in Vivado 2018.2 XSIM. Behavior under other simulators or synthesis tools may differ.
2. **Directed Mutants:** Testing focused on the four critical parameter and boundary architecture failure modes approved for verification. Comprehensive automated random mutation (e.g., bit-flip or operator replacement across all modules) was outside the v1.0.3 patch scope.

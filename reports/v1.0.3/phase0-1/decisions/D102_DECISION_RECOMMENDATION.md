# D-102 Decision Recommendation: Invalid Parameter Rejection Mechanism (Reconciled)

**Project:** Secure Vending Machine Controller (v1.0.3 Patch Release)  
**Topic:** Rejection Mechanism for Invalid `PRODUCT_COUNT` Values (`PRODUCT_COUNT < 1 || PRODUCT_COUNT > 32`)  
**Target RTL File:** `rtl/top.sv` (Authoritative instance owner)  
**Technical Evidence Status:** **COMPLETE & VERIFIED** (N=0 and N=33 rejected; N=5 and N=32 accepted)  
**Maintainer Approval Status:** **APPROVED** (Approved in conversation conditional on N=33 evidence; condition now satisfied)  
**Implementation Status:** Design recommendation only; no project RTL modified in Phase 0/1  
**Evidence Source:** [VIVADO_PROBE_RESULTS.md](file:///C:/Users/User/Documents/Projects/v1.0.3-phase0-1/reports/final/VIVADO_PROBE_RESULTS.md) and [N33_PROBE_RESULT.log](file:///C:/Users/User/Documents/Projects/v1.0.3-phase0-1/reports/final/N33_PROBE_RESULT.log)

---

## 1. Decision Problem Statement

The v1.0.3 architecture introduces parameterization of `PRODUCT_COUNT` across the Secure Vending Machine Controller, allowing valid configurations from `1` to `32` (with default `5`). Any configuration outside `[1, 32]` (such as `0` or `33`) is illegal.

Decision **D-102** resolves:
> *How should an invalid `PRODUCT_COUNT` parameter value be detected and rejected by the toolchain?*

Three candidate mechanisms were evaluated against the target Vivado 2018.2 toolchain:
1. **Mechanism 1 (M1):** Generate-time SystemVerilog `$error` inside a generate block (`probe_a_elab_error.sv`).
2. **Mechanism 2 (M2):** Undefined module instantiation inside an unselected generate block (`probe_b_undefined_module.sv` and `extra/probe_b_undefined_module_n33.sv`).
3. **Mechanism 3 (M3):** Runtime `$fatal` inside an `initial` procedural block (`probe_c_runtime_fatal.sv`).

---

## 2. Experimental Comparison Across Boundary Conditions

| Evaluation Criterion | Mechanism 1: Generate `$error` | Mechanism 2: Undefined Module | Mechanism 3: Runtime `$fatal` |
|---|---|---|---|
| **Underlying SV Construct** | `generate if (...) $error(...)` | `generate if (...) PRODUCT_COUNT_OUT_OF_RANGE_see_docs u_invalid();` | `initial if (...) $fatal(1, ...)` |
| **Valid Nominal (`N=5`) Elaboration** | Succeeded (Exit 0) | **Succeeded (Exit 0)** | Succeeded (Exit 0) |
| **Valid Boundary (`N=32`) Elaboration** | Not tested | **Succeeded (Exit 0)** | Not tested |
| **Invalid Lower (`N=0`) Elaboration** | **Succeeded (Exit 0)** (Failed to reject) | **FAILS (Exit 1, VRFC 10-2063)** | Succeeded (Exit 0) |
| **Invalid Upper (`N=33`) Elaboration** | Not tested | **FAILS (Exit 1, VRFC 10-2063)** | Not tested |
| **Diagnostic Stage** | Elaboration warning | **Static Elaboration Error** | Runtime simulation error |
| **Diagnostic Code / Text** | `WARNING: [#UNDEF] PROBE_A...` | `ERROR: [VRFC 10-2063] Module <PRODUCT_COUNT_OUT_OF_RANGE_see_docs> not found` | `Fatal: PROBE_C...` at 0 ps |
| **Snapshot Created for Invalid Top?** | **YES** (`pa_bad` created) | **NO** (Static elaboration aborts) | **YES** (`pc_bad` created) |
| **Simulation Exit Code on Invalid Run**| `0` (runs cleanly) | N/A (cannot simulate) | `0` (xsim terminates on `$finish`) |
| **Toolchain Viability** | **UNUSABLE** | **RECOMMENDED & VERIFIED** | **RUNTIME BACKSTOP ONLY** |

---

## 3. Detailed Evidence Analysis

### 3.1 Mechanism 1 (Generate `$error`) Is Unusable
In Vivado 2018.2 (`xelab`):
* `$error` inside a generate block is downgraded to `WARNING: [#UNDEF] ...`.
* Static elaboration continues, data flow analysis completes, and compilation builds snapshot `pa_bad`.
* `xelab` returns exit code `0`. Subsequent execution with `xsim pa_bad -runall` executes cleanly and exits `0`.
* **Conclusion:** Mechanism 1 provides zero enforcement. Illegal configurations elaborate and run undetected.

### 3.2 Mechanism 2 (Undefined Module Fallback) Is Robust and Fully Verified
Mechanism 2 relies on conditional elaboration semantics:
* **Valid Configurations (N=5 default, N=32 upper boundary):** The condition `(PRODUCT_COUNT < 1 || PRODUCT_COUNT > 32)` evaluates false. Vivado 2018.2 ignores unselected generate branches, neither requiring nor binding `PRODUCT_COUNT_OUT_OF_RANGE_see_docs`. Static elaboration succeeds with exit code `0`, and a valid simulation snapshot is produced.
* **Invalid Lower Boundary (N=0):** The condition evaluates true. Static elaboration attempts to bind the instance and immediately halts with:
  ```text
  ERROR: [VRFC 10-2063] Module <PRODUCT_COUNT_OUT_OF_RANGE_see_docs> not found while processing module instance <g_bad_count.u_invalid>
  ERROR: [XSIM 43-3322] Static elaboration of top level Verilog design unit(s) in library work failed.
  ```
  Process exit code is `1`. No simulation snapshot is produced.
* **Invalid Upper Boundary (N=33):** Executed in an isolated test environment (`sim_n33`). The condition evaluates true. Static elaboration halts immediately with identical diagnostic `ERROR: [VRFC 10-2063]` and exit code `1`. No snapshot is produced.
* **Conclusion:** Mechanism 2 reliably halts static elaboration for all invalid values on both sides of the legal interval `[1, 32]`.

### 3.3 Mechanism 3 (Runtime `$fatal`) Evaluation
* `xelab` elaborates the invalid module without complaint.
* `xsim` executes the `initial` block at `0 ps` and halts before functional logic executes.
* However, because `xsim` handles `$fatal` by invoking `$finish`, `xsim.bat` returns process exit code `0`. Automated regression testing cannot check process exit code alone; it would require scraping `xsim.log`.
* More fundamentally, invalid hardware should not elaborate or produce bitstreams/simulation images.

---

## 4. Reconciled Architectural Specification

### 4.1 Authoritative Validation Ownership
As established in the Phase 1 Implementation Plan:
1. **Single Point of Validation:** The public `PRODUCT_COUNT` parameter is validated **authoritatively in `rtl/top.sv` only**.
2. **Parameter Propagation:** `rtl/top.sv` passes `PRODUCT_COUNT` down to `security_engine` and `inventory_manager`.
3. **No Duplicate Competing Validation:** `inventory_manager` does **not** instantiate a second competing validation block.
4. **Structural Clamp (`PC_SAFE`):** Submodules (`security_engine.sv` and `inventory_manager.sv`) declare:
   ```systemverilog
   localparam int unsigned PC_SAFE = (PRODUCT_COUNT < 1) ? 1 :
                                     (PRODUCT_COUNT > transaction_pkg::PRODUCT_COUNT_MAX) ? transaction_pkg::PRODUCT_COUNT_MAX :
                                     PRODUCT_COUNT;
   ```
   This ensures arrays (`[0:PC_SAFE-1]`) and internal comparisons remain structurally legal during static elaboration until the top-level Mechanism 2 construct halts `xelab`.

### 4.2 Approved Mechanism Implementation Pattern (Illustrative Sketch)

When authorized for Phase 2 implementation, `rtl/top.sv` will include the tested construct:

```systemverilog
// Authoritative parameter range validation (Vivado 2018.2 compatible)
generate
    if (PRODUCT_COUNT < 1 || PRODUCT_COUNT > transaction_pkg::PRODUCT_COUNT_MAX) begin : g_bad_count
        // Deliberately undefined module instantiation triggers xelab error VRFC 10-2063
        PRODUCT_COUNT_OUT_OF_RANGE_see_docs u_invalid ();
    end
endgenerate
```

> [!NOTE]
> The code block above is an illustrative design specification approved for Phase 2. In compliance with Phase 0/1 safety restrictions, **no project RTL has been modified in this task**.

### 4.3 Negative Regression Test Design
Negative parameter testbenches (`tb_param_count_0` and `tb_param_count_33`):
* **Target Stage:** `xelab` (NOT `xsim`).
* **Expected Exit Code:** `1` (Non-zero).
* **Diagnostic Verification:** The regression runner must verify `xelab.log` for string `PRODUCT_COUNT_OUT_OF_RANGE_see_docs` or code `VRFC 10-2063`.

---

## 5. Scope and Toolchain Boundaries

* **Simulation Coverage:** Verified on Vivado 2018.2 XSIM (`xvlog`, `xelab`, `xsim`).
* **Synthesis Behavior:** **UNVERIFIED.** While Vivado Synthesis shares front-end elaboration routines, no synthesis runs were performed or claimed as verified during this simulation-focused evidence phase.

---

## 6. Status and Maintainer Approval Summary

* **Technical Evidence Status:** **Complete and Verified.** Both lower-bound (N=0) and upper-bound (N=33) rejections, as well as valid boundaries (N=5, N=32), have been empirically proven on Vivado 2018.2.
* **Maintainer Approval:** **Approved.** The project maintainer explicitly approved Mechanism 2 conditional on the N=33 negative test. With the successful execution of N=33, this condition is fully satisfied.
* **Decision Status:** **Ready for Phase 2 Implementation.**

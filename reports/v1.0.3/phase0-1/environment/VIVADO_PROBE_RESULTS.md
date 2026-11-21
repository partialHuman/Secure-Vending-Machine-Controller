# Vivado 2018.2 Probe Results Report (Probes A–E & N=33 Verification)

**Project:** Secure Vending Machine Controller (v1.0.3 Patch Release)  
**Task:** Experimental Evaluation of Tool Compatibility Probes A–E and Upper Boundary N=33  
**Date:** 2026-11-18 (Reconciled with N=33 Execution)  
**Toolchain:** Xilinx Vivado Design Suite 2018.2 (SW Build 2258646, 64-bit)  
**Primary Working Directory:** `C:\Users\User\Documents\Projects\v1.0.3-phase0-1\probes`  
**Isolated N=33 Working Directory:** `C:\Users\User\Documents\Projects\v1.0.3-phase0-1\probes\extra\sim_n33`  
**Execution Logs:**
- Full Probes A–E Log: [probe_execution_raw.log](file:///C:/Users/User/Documents/Projects/v1.0.3-phase0-1/reports/final/logs/probe_execution_raw.log)
- Isolated N=33 Log: [N33_PROBE_RESULT.log](file:///C:/Users/User/Documents/Projects/v1.0.3-phase0-1/reports/final/N33_PROBE_RESULT.log)

---

## 1. Executive Summary of Probe Execution

All SystemVerilog compatibility probes (`probe_a_elab_error.sv` through `probe_e_depth_and_functions.sv`), plus the isolated upper-bound test `probe_b_undefined_module_n33.sv`, were executed against the actual installed Vivado 2018.2 toolchain.

No original probe source files were modified. The additional N=33 test and N=32 control test were created in an isolated directory (`probes/extra/`) using unique module identifiers to avoid any work-library collisions.

### Key Outcomes:
* **Compilation (`xvlog -sv`):** All original 5 probe files and the new N=33 test file compiled into library `work` with exit code `0` and zero warnings/errors.
* **Probe A (`$error` in generate-if):** **FAILED AS REJECTION MECHANISM.** Vivado 2018.2 downgrades generate-time `$error` to an informational warning and elaborates the invalid top level successfully with exit code `0`.
* **Probe B (Undefined module in unselected generate branch):** **PASSED COMPLETELY.**
  - Valid N=5: Elaborates cleanly with exit code `0`.
  - Invalid N=0: Fails static elaboration immediately with exit code `1` and diagnostic `ERROR: [VRFC 10-2063] Module <PRODUCT_COUNT_OUT_OF_RANGE_see_docs> not found`.
  - Mandatory Invalid N=33: Fails static elaboration immediately with exit code `1` and identical diagnostic `VRFC 10-2063`.
  - Optional Control Valid N=32: Elaborates cleanly with exit code `0`.
* **Probe C (Runtime `$fatal`):** **FUNCTIONAL RUNTIME SAFEGUARD ONLY.** Valid top simulates and prints `PROBE_C_OK` (exit `0`). Invalid top elaborates with exit code `0` and halts simulation at time `0 ps`.
* **Probe D (Parameters & SV features):** **PASSED COMPLETELY.** Package parameter `2**W`, default module parameters, guarded array reads, and hierarchical testbench parameter access (`dut.PC`) all verified.
* **Probe E (Array depth, bounds & constant functions):** **PASSED COMPLETELY.** `$size`, `$bits`, out-of-range read (`$isunknown=1`), hierarchical localparam (`dut.DEPTH`), and package constant functions (`safe_count`) all verified without modification.

---

## 2. Compilation Results

### 2.1 Baseline Compilation (Probes A–E)
* **Command:** `xvlog -sv probe_a_elab_error.sv probe_b_undefined_module.sv probe_c_runtime_fatal.sv probe_d_param_features.sv probe_e_depth_and_functions.sv`
* **Stage:** `xvlog`
* **Exit Code:** `0`
* **Output / Diagnostic Log:**
```text
INFO: [VRFC 10-2263] Analyzing SystemVerilog file "C:/Users/User/Documents/Projects/v1.0.3-phase0-1/probes/probe_a_elab_error.sv" into library work
INFO: [VRFC 10-311] analyzing module probe_a_core
INFO: [VRFC 10-311] analyzing module probe_a_ok
INFO: [VRFC 10-311] analyzing module probe_a_bad
INFO: [VRFC 10-2263] Analyzing SystemVerilog file "C:/Users/User/Documents/Projects/v1.0.3-phase0-1/probes/probe_b_undefined_module.sv" into library work
INFO: [VRFC 10-311] analyzing module probe_b_core
INFO: [VRFC 10-311] analyzing module probe_b_ok
INFO: [VRFC 10-311] analyzing module probe_b_bad
INFO: [VRFC 10-2263] Analyzing SystemVerilog file "C:/Users/User/Documents/Projects/v1.0.3-phase0-1/probes/probe_c_runtime_fatal.sv" into library work
INFO: [VRFC 10-311] analyzing module probe_c_core
INFO: [VRFC 10-311] analyzing module probe_c_ok
INFO: [VRFC 10-311] analyzing module probe_c_bad
INFO: [VRFC 10-2263] Analyzing SystemVerilog file "C:/Users/User/Documents/Projects/v1.0.3-phase0-1/probes/probe_d_param_features.sv" into library work
INFO: [VRFC 10-311] analyzing module probe_d_dut
INFO: [VRFC 10-311] analyzing module probe_d_tb
INFO: [VRFC 10-2263] Analyzing SystemVerilog file "C:/Users/User/Documents/Projects/v1.0.3-phase0-1/probes/probe_e_depth_and_functions.sv" into library work
INFO: [VRFC 10-311] analyzing module probe_e_dut
INFO: [VRFC 10-311] analyzing module probe_e_tb
```

### 2.2 Isolated N=33 Test Compilation
* **Working Directory:** `C:\Users\User\Documents\Projects\v1.0.3-phase0-1\probes\extra\sim_n33`
* **Command:** `xvlog -sv ..\probe_b_undefined_module_n33.sv`
* **Stage:** `xvlog`
* **Exit Code:** `0`
* **Output / Diagnostic Log:**
```text
INFO: [VRFC 10-2263] Analyzing SystemVerilog file "C:/Users/User/Documents/Projects/v1.0.3-phase0-1/probes/extra/probe_b_undefined_module_n33.sv" into library work
INFO: [VRFC 10-311] analyzing module probe_b_n33_core
INFO: [VRFC 10-311] analyzing module probe_b_bad_33
INFO: [VRFC 10-311] analyzing module probe_b_ok_32
```

---

## 3. Detailed Results by Probe

### 3.1 Probe A — Generate-Time `$error`
* **Source:** `probes/probe_a_elab_error.sv`
* **A-OK (`probe_a_ok`, N=5):** `xelab probe_a_ok -s pa_ok` -> Exit code `0`. Snapshot built.
* **A-BAD (`probe_a_bad`, N=0):** `xelab probe_a_bad -s pa_bad` -> Exit code `0` (FAILED REJECTION).
* **Diagnostic Emitted:**
```text
WARNING: [#UNDEF] PROBE_A: N=0 is outside 1..32 [C:/Users/User/Documents/Projects/v1.0.3-phase0-1/probes/probe_a_elab_error.sv:7]
```
* **Supplemental Simulation Check:** `xsim pa_bad -runall` -> Exit code `0`. Executes cleanly without failure.
* **Verdict:** **UNUSABLE.** Generate `$error` cannot block invalid configuration elaboration.

---

### 3.2 Probe B — Undefined Module Fallback (N=5 and N=0)
* **Source:** `probes/probe_b_undefined_module.sv`
* **B-OK (`probe_b_ok`, N=5):** `xelab probe_b_ok -s pb_ok` -> Exit code `0`. Snapshot built.
* **B-BAD (`probe_b_bad`, N=0):** `xelab probe_b_bad -s pb_bad` -> Exit code `1`.
* **Diagnostic Emitted:**
```text
ERROR: [VRFC 10-2063] Module <PRODUCT_COUNT_OUT_OF_RANGE_see_docs> not found while processing module instance <g_bad_count.u_invalid> [C:/Users/User/Documents/Projects/v1.0.3-phase0-1/probes/probe_b_undefined_module.sv:7]
ERROR: [XSIM 43-3322] Static elaboration of top level Verilog design unit(s) in library work failed.
```
* **Snapshot Created:** None.
* **Verdict:** **PASSED.** Lower boundary rejection verified at elaboration time.

---

### 3.3 Probe B Extra — Upper Boundary N=33 Rejection & N=32 Control
* **Source:** `probes/extra/probe_b_undefined_module_n33.sv`
* **Isolated Execution Directory:** `probes/extra/sim_n33`

#### Mandatory Negative Test: `probe_b_bad_33` (N=33)
* **Command:** `xelab probe_b_bad_33 -s pb_bad_33`
* **Stage:** `xelab`
* **Exit Code:** `1`
* **Expected:** Elaboration fails with non-zero exit code and module-not-found diagnostic.
* **Actual:** Elaboration **failed with exit code 1** during static elaboration.
* **Diagnostic Emitted:**
```text
Vivado Simulator 2018.2
Copyright 1986-1999, 2001-2018 Xilinx, Inc. All Rights Reserved.
Running: D:/Xilinx/Vivado/2018.2/bin/unwrapped/win64.o/xelab.exe probe_b_bad_33 -s pb_bad_33 
Multi-threading is on. Using 10 slave threads.
Starting static elaboration
ERROR: [VRFC 10-2063] Module <PRODUCT_COUNT_OUT_OF_RANGE_see_docs> not found while processing module instance <g_bad_count.u_invalid> [C:/Users/User/Documents/Projects/v1.0.3-phase0-1/probes/extra/probe_b_undefined_module_n33.sv:9]
ERROR: [XSIM 43-3322] Static elaboration of top level Verilog design unit(s) in library work failed.
```
* **Snapshot Created:** `False` (Verified non-existent).
* **Verdict:** **PASSED.** Upper boundary rejection (N=33) verified at elaboration time.

#### Optional Control Test: `probe_b_ok_32` (Boundary Valid N=32)
* **Command:** `xelab probe_b_ok_32 -s pb_ok_32`
* **Stage:** `xelab`
* **Exit Code:** `0`
* **Expected:** Elaboration succeeds with exit code 0.
* **Actual:** Elaboration **succeeded with exit code 0**. Built snapshot `pb_ok_32`.
* **Diagnostic Emitted:** None (clean static elaboration and flow analysis).
* **Snapshot Created:** `True` (Verified present in `xsim.dir/pb_ok_32`).
* **Verdict:** **PASSED.** Maximum valid boundary (N=32) elaborates cleanly.

---

### 3.4 Probe C — Runtime `$fatal`
* **Source:** `probes/probe_c_runtime_fatal.sv`
* **C-OK (`probe_c_ok`, N=5):** `xelab` exit `0`; `xsim` exit `0`. Prints `PROBE_C_OK` at 10 ns.
* **C-BAD (`probe_c_bad`, N=0):** `xelab` exit `0`; `xsim` exit `0`.
* **Diagnostic Emitted:**
```text
Fatal: PROBE_C: N=0 is outside 1..32
Time: 0 ps  Iteration: 0  Process: /probe_c_bad/u/Initial5_0
$finish called at time : 0 fs
```
* **Verdict:** Runtime safeguard functional, but does not stop elaboration and exits xsim with code 0.

---

### 3.5 Probe D — Parameters & Language Features
* **Source:** `probes/probe_d_param_features.sv`
* **Commands:** `xelab probe_d_tb -s pd` (exit 0) -> `xsim pd -runall` (exit 0).
* **Observed Output:**
```text
PROBE_D dut: PC=8 MAX=32 rd(out-of-range)=0
PROBE_D tb reads dut.PC=8 (expect 8)
```
* **Verdict:** **PASSED.** 100% match with expected values.

---

### 3.6 Probe E — Array Depth, Bounds & Constant Functions
* **Source:** `probes/probe_e_depth_and_functions.sv`
* **Commands:** `xelab probe_e_tb -s pe` (exit 0) -> `xsim pe -runall` (exit 0).
* **Elaboration Warning (Expected):**
```text
WARNING: [VRFC 10-1783] select index 8 into qty_mem is out of bounds
```
* **Observed Output:**
```text
PROBE_E1 size    = 8 (expect 8)
PROBE_E1 bits    = 64 (expect 64)
PROBE_E2 oob read isunknown = 1 (expect 1)
PROBE_E2 last valid = 20 (expect 20)
PROBE_E3 dut.DEPTH = 8 (expect 8)
PROBE_E4 safe_count(0)=1 safe_count(33)=32 safe_count(5)=5 (expect 1 32 5)
```
* **Verdict:** **PASSED.** Verified without modifying any lines of code.

---

## 4. Comprehensive Command and Exit Code Matrix

| Probe | Stage | Command | Exit Code | Expected Behavior | Observed Behavior | Diagnostic Text | Result |
|---|---|---|---|---|---|---|---|
| **All Baseline** | `xvlog` | `xvlog -sv probe_a_elab_error.sv ... probe_e_depth_and_functions.sv` | **0** | Clean compile | Clean compile | `INFO: [VRFC 10-2263] Analyzing SystemVerilog file ...` | **PASS** |
| **A-OK** | `xelab` | `xelab probe_a_ok -s pa_ok` | **0** | Snapshot built | Snapshot built | `Built simulation snapshot pa_ok` | **PASS** |
| **A-BAD** | `xelab` | `xelab probe_a_bad -s pa_bad` | **0** | Non-zero exit code | Exit code 0 (downgraded to warning) | `WARNING: [#UNDEF] PROBE_A: N=0 is outside 1..32` | **FAIL** (Not usable for rejection) |
| **A-BAD** | `xsim` | `xsim pa_bad -runall` | **0** | N/A (Diagnostic check) | Executes without error | Clean termination | **FAIL** (Did not reject) |
| **B-OK** | `xelab` | `xelab probe_b_ok -s pb_ok` | **0** | Snapshot built | Snapshot built | `Built simulation snapshot pb_ok` | **PASS** |
| **B-BAD (N=0)**| `xelab` | `xelab probe_b_bad -s pb_bad` | **1** | Non-zero exit + module not found | Exit 1 + module not found | `ERROR: [VRFC 10-2063] Module <PRODUCT_COUNT_OUT_OF_RANGE_see_docs> not found` | **PASS** (Rejection at N=0 verified) |
| **N=33 Compile** | `xvlog` | `xvlog -sv ..\probe_b_undefined_module_n33.sv` | **0** | Clean compile | Clean compile | `INFO: [VRFC 10-2263] Analyzing SystemVerilog file ...` | **PASS** |
| **B-BAD (N=33)**| `xelab` | `xelab probe_b_bad_33 -s pb_bad_33` | **1** | Non-zero exit + module not found | Exit 1 + module not found | `ERROR: [VRFC 10-2063] Module <PRODUCT_COUNT_OUT_OF_RANGE_see_docs> not found` | **PASS** (Rejection at N=33 verified) |
| **B-OK (N=32)** | `xelab` | `xelab probe_b_ok_32 -s pb_ok_32` | **0** | Snapshot built | Snapshot built | `Built simulation snapshot pb_ok_32` | **PASS** (Boundary N=32 accepted) |
| **C-OK** | `xsim` | `xsim pc_ok -runall` | **0** | `PROBE_C_OK` at 10 ns | `PROBE_C_OK` at 10 ns | `PROBE_C_OK` | **PASS** |
| **C-BAD** | `xsim` | `xsim pc_bad -runall` | **0** | Fatal at time 0 ps; no survive | Fatal at time 0 ps; no survive | `Fatal: PROBE_C: N=0 is outside 1..32` | **PASS** (Runtime only; exit code 0) |
| **D** | `xsim` | `xsim pd -runall` | **0** | PC=8 MAX=32 rd=0; tb reads PC=8 | Matches expected output | `PROBE_D dut: PC=8 MAX=32 rd(out-of-range)=0` | **PASS** |
| **E** | `xsim` | `xsim pe -runall` | **0** | E1=8/64, E2=1/20, E3=8, E4=1 32 5 | Matches expected output | `PROBE_E1 size = 8 ... PROBE_E4 safe_count(...)` | **PASS** |

---

## 5. Scope and Limitations

* **Target RTL Path:** The validated parameter check architecture applies strictly to `rtl/top.sv` as the authoritative top level.
* **D-103 Verification Boundary:** Probe E verified the underlying SystemVerilog language features (package constant functions, `$size`, `$bits`, out-of-range reads on unpacked arrays, hierarchical localparam access) in an isolated probe module. Actual `inventory_manager.sv` array depth and parameter propagation have **not** been tested in project RTL and constitute Phase 2 verification requirements.
* **D-108 Verification Boundary:** Probes D and E demonstrated isolated guarded-index and out-of-range read behavior in standalone probe modules. Actual `inventory_manager.sv` invalid-access handling has **not** been tested in project RTL; Phase 2 requires direct unit tests in `tb_inventory_manager.sv` (including per-entry memory snapshots before and after invalid operations).
* **Synthesis Behavior Unverified:** All results documented above reflect simulation toolchain behavior (`xvlog`, `xelab`, `xsim`). Synthesis rejection under `synth_design` remains unverified by experimental evidence and is not claimed as verified.

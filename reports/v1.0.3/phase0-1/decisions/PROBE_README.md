# Tool Probes A–E and N=33 Verification Guide (Reconciled)

**Project:** Secure Vending Machine Controller (v1.0.3 Patch Release)  
**Target Toolchain:** Xilinx Vivado Design Suite 2018.2 / XSIM (SW Build 2258646, 64-bit)  
**Host Environment:** Windows 11 Pro 64-bit  
**Purpose:** Empirically verify the parameter rejection mechanism for **D-102** and confirm SystemVerilog 2012 features required by the v1.0.3 implementation plan.  
**Historical Status:** All probes have been executed; results are fully verified and recorded.

---

## 1. Summary of Experimental Results

| Probe | File | Tested Mechanism / Feature | Observed Stage & Exit Code | Verdict |
|---|---|---|---|---|
| **A** | `probe_a_elab_error.sv` | Generate-time `$error` (N=0 vs N=5) | `xelab`: Exit `0` for both; downgraded to warning | **Unusable** (Mechanism 1 fails) |
| **B** | `probe_b_undefined_module.sv` | Undefined module fallback (N=0 vs N=5) | `xelab`: N=5 Exit `0`; N=0 Exit `1` (`VRFC 10-2063`) | **Accepted** (Mechanism 2 verified) |
| **B-N33** | `extra/probe_b_undefined_module_n33.sv` | Undefined module upper boundary (N=33 vs N=32) | `xelab`: N=32 Exit `0`; N=33 Exit `1` (`VRFC 10-2063`) | **Accepted** (Upper boundary verified) |
| **C** | `probe_c_runtime_fatal.sv` | Runtime `$fatal` (N=0 vs N=5) | `xelab`: Exit `0`; `xsim`: N=0 halts at 0 ps (Exit `0`) | **Runtime fallback only** |
| **D** | `probe_d_param_features.sv` | `2**W`, package defaults, guarded reads, `dut.PC` | `xsim`: Exit `0`; 100% expected output | **Fully verified** |
| **E** | `probe_e_depth_and_functions.sv` | `$size`, `$bits`, `$isunknown`, constant functions | `xsim`: Exit `0`; all E1–E4 checks pass unmodified | **Fully verified** |

---

## 2. D-102 Resolution and Conclusion

* **Mechanism 1 (Generate `$error`):** Rejected. Vivado 2018.2 treats `$error` in generate blocks as an informational warning (`WARNING: [#UNDEF] ...`) and continues static elaboration, generating a runnable simulation snapshot.
* **Mechanism 2 (Undefined Module Fallback):** **Adopted and Approved.** Valid parameters (`1 <= N <= 32`) leave the invalid generate branch unselected, elaborating cleanly with exit code `0`. Invalid parameters (`N=0` and `N=33`) trigger static elaboration error `VRFC 10-2063` and halt elaboration with exit code `1`.
* **Mechanism 3 (Runtime `$fatal`):** Viable runtime safeguard, but cannot halt elaboration.

---

## 3. Reproduction Instructions

### 3.1 Reproducing Baseline Probes A–E

From directory `probes/` with Vivado `bin` on `PATH`:

```powershell
# 1. Compile all 5 probe sources
xvlog -sv probe_a_elab_error.sv probe_b_undefined_module.sv probe_c_runtime_fatal.sv probe_d_param_features.sv probe_e_depth_and_functions.sv

# 2. Probe A (Generate $error)
xelab probe_a_ok  -s pa_ok   # Exit code 0
xelab probe_a_bad -s pa_bad  # Exit code 0 (WARNING emitted, snapshot created)

# 3. Probe B (Undefined module fallback)
xelab probe_b_ok  -s pb_ok   # Exit code 0 (Snapshot created)
xelab probe_b_bad -s pb_bad  # Exit code 1 (ERROR: [VRFC 10-2063], snapshot NOT created)

# 4. Probe C (Runtime $fatal)
xelab probe_c_ok  -s pc_ok  ; xsim pc_ok  -runall  # Prints PROBE_C_OK
xelab probe_c_bad -s pc_bad ; xsim pc_bad -runall  # Halts at 0 ps with Fatal message

# 5. Probe D (Language features)
xelab probe_d_tb -s pd ; xsim pd -runall
# Output: PROBE_D dut: PC=8 MAX=32 rd(out-of-range)=0
#         PROBE_D tb reads dut.PC=8 (expect 8)

# 6. Probe E (Array depth and constant functions)
xelab probe_e_tb -s pe ; xsim pe -runall
# Output: PROBE_E1 size = 8, bits = 64
#         PROBE_E2 oob read isunknown = 1, last valid = 20
#         PROBE_E3 dut.DEPTH = 8
#         PROBE_E4 safe_count(0)=1 safe_count(33)=32 safe_count(5)=5
```

### 3.2 Reproducing Isolated N=33 Probe

From an isolated working directory (e.g., `probes/extra/sim_n33`):

```powershell
# 1. Compile isolated test source
xvlog -sv ..\probe_b_undefined_module_n33.sv

# 2. Execute mandatory N=33 negative test
xelab probe_b_bad_33 -s pb_bad_33
# Expected: Exit code 1
# Diagnostic: ERROR: [VRFC 10-2063] Module <PRODUCT_COUNT_OUT_OF_RANGE_see_docs> not found
# Snapshot pb_bad_33 is NOT created

# 3. Execute optional N=32 valid boundary control test
xelab probe_b_ok_32 -s pb_ok_32
# Expected: Exit code 0
# Snapshot pb_ok_32 IS created
```

---

## 4. Scope, Verification Boundaries & Synthesis Note

* **Language Features vs Project RTL:** Probes D and E verified the underlying SystemVerilog language features in isolated testbenches. They do not claim verification of actual `inventory_manager.sv` array depth, parameter propagation, or safe invalid-access handling, which are explicit Phase 2 verification requirements to be proven in `tb_inventory_manager.sv` with per-entry snapshots.
* **Synthesis Behavior:** The verified behaviors apply to the Vivado 2018.2 simulation toolchain (`xvlog`, `xelab`, `xsim`). Synthesis behavior under `synth_design` remains unverified by experimental evidence and is not required for this simulation-only patch release.

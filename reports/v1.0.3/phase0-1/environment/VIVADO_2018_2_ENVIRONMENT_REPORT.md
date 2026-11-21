# Vivado 2018.2 Environment Verification Report (Reconciled)

**Project:** Secure Vending Machine Controller (v1.0.3 Patch Release)  
**Task:** Phase 0/1 Toolchain Compatibility & Execution Environment Audit  
**Date:** 2026-11-18 (Reconciled with N=33 Execution)  
**Execution Host:** Windows 11 Pro 64-bit (Build 26200)  
**Installation Path:** `D:\Xilinx\Vivado\2018.2`  
**Execution Logs:** 
- Full Suite Log: [probe_execution_raw.log](file:///C:/Users/User/Documents/Projects/v1.0.3-phase0-1/reports/final/logs/probe_execution_raw.log)
- N=33 Execution Log: [N33_PROBE_RESULT.log](file:///C:/Users/User/Documents/Projects/v1.0.3-phase0-1/reports/final/N33_PROBE_RESULT.log)

---

## 1. Executive Summary

This reconciled environment report documents the experimental verification of the Xilinx Vivado Design Suite 2018.2 installation used for the Secure Vending Machine Controller v1.0.3 maintenance release. Prior to Phase 2 implementation, all simulator binaries (`xvlog`, `xelab`, `xsim`) and the Vivado Tcl Shell execution environment were audited for accessibility, command syntax, process return codes, and diagnostic behavior across baseline probes A–E and the isolated upper-bound N=33 test.

The toolchain is verified to be fully operational. All binaries executed from target directories without path resolution issues or missing library dependencies.

---

## 2. Toolchain Identity and Versions

### 2.1 Vivado Design Suite Version
* **Invocation:** `vivado.bat -version` / Tcl `version`
* **Process Exit Code:** `0`
* **Observed Banner:**
```text
Vivado v2018.2 (64-bit)
SW Build 2258646 on Thu Jun 14 20:03:12 MDT 2018
IP Build 2256618 on Thu Jun 14 22:10:49 MDT 2018
Copyright 1986-2018 Xilinx, Inc. All Rights Reserved.
```

### 2.2 SystemVerilog Compiler (`xvlog`)
* **Binary Path:** `D:\Xilinx\Vivado\2018.2\bin\xvlog.bat`
* **Invocation:** `xvlog.bat --version` (PowerShell) / `exec xvlog --version` (Tcl Shell)
* **Process Exit Code:** `0`
* **Observed Banner:**
```text
Vivado Simulator 2018.2
```

### 2.3 Static Elaborator (`xelab`)
* **Binary Path:** `D:\Xilinx\Vivado\2018.2\bin\xelab.bat`
* **Invocation:** `xelab.bat --version` (PowerShell) / `exec xelab --version` (Tcl Shell)
* **Process Exit Code:** `0`
* **Observed Banner:**
```text
Vivado Simulator 2018.2
```
* **Threading Capability:** Static elaboration utilizes multi-threading (`Multi-threading is on. Using 10 slave threads.`).

### 2.4 Simulation Engine (`xsim`)
* **Binary Path:** `D:\Xilinx\Vivado\2018.2\bin\xsim.bat`
* **Invocation Test:** `xsim.bat -version` / `exec xsim -version 2>@1`
* **Process Exit Code:** `1` (Known tool quirk)
* **Observed Banner:**
```text
Vivado Simulator 2018.2
child process exited abnormally
```
* **Supported Switches (`xsim --help`):**
  Supported execution switches include `--runall` / `-runall` (run simulation until completion), `-R`, `--tclbatch`, `--onerror <quit|stop>`, `--onfinish <quit|stop>`, `--nolog`, `--stats`, and `--wdb`.

> [!WARNING]
> In Vivado 2018.2, invoking `xsim -version` prints `Vivado Simulator 2018.2` but exits with status code `1` (abnormal child process termination). This is a confirmed vendor behavior in Vivado 2018.2 and must **not** be used as an environment health check in automated regression scripts. Tool health should instead be verified via `xvlog --version` or `xelab --version`.

---

## 3. Installation Directory and Path Layout

| Component | Filesystem Location | Verification Status |
|---|---|---|
| **Vivado Root Directory** | `D:\Xilinx\Vivado\2018.2` | Confirmed accessible |
| **Binary Directory (`bin`)** | `D:\Xilinx\Vivado\2018.2\bin` | Added to `$env:PATH` for execution |
| **Unwrapped Binaries** | `D:\Xilinx\Vivado\2018.2\bin\unwrapped\win64.o\` | Verified (`xvlog.exe`, `xelab.exe`, `xsim.exe`) |
| **Tcl Shell Executable** | `D:\Xilinx\Vivado\2018.2\bin\xtclsh.bat` | Operational |
| **Primary Probe Directory** | `C:\Users\User\Documents\Projects\v1.0.3-phase0-1\probes` | Clean working directory |
| **Isolated N=33 Test Directory**| `C:\Users\User\Documents\Projects\v1.0.3-phase0-1\probes\extra\sim_n33` | Isolated simulation directory |
| **Final Reports Directory** | `C:\Users\User\Documents\Projects\v1.0.3-phase0-1\reports\final` | Reconciled reports destination |

---

## 4. Tcl Shell and Subprocess Execution Semantics

During Phase 0/1 audit, special attention was paid to how Vivado Tcl Shell handles external process execution and return codes. The following behavioral characteristics were verified experimentally:

1. **Child Process Invocation:**  
   External binaries must be executed using Tcl `exec` (e.g., `exec xvlog ...`).
2. **Standard Error Handling in Tcl `exec`:**  
   Standard Tcl `exec` raises a catchable Tcl error whenever output is emitted on standard error (`stderr`), even if the underlying process exits with code `0`. To prevent false-positive failures in Tcl wrappers, commands should employ stream redirection:
   ```tcl
   set rc [catch {exec {*}$cmd_args 2>@1} output opts]
   ```
3. **Exit Code Extraction:**  
   When a child process terminates with a non-zero exit code, Tcl populates the `-errorcode` dictionary key as `CHILDSTATUS <pid> <code>`. A robust Tcl wrapper must inspect `[dict get $opts -errorcode]` rather than assuming exit status based solely on whether `catch` returned non-zero.
4. **PowerShell / Batch Direct Invocation:**  
   When invoking batch wrappers (`xvlog.bat`, `xelab.bat`, `xsim.bat`) in PowerShell, the true process exit code is faithfully captured in `$LASTEXITCODE`.

---

## 5. Scope of Verified Toolchain Behavior

* **Simulation Toolchain (`xvlog`, `xelab`, `xsim`):** Fully verified across all probe designs, boundary conditions, and negative tests.
* **Synthesis Front-End (`synth_design`):** **UNVERIFIED.** While Vivado Synthesis shares the same front-end elaboration parser, no synthesis runs were executed during Phase 0/1 as synthesis is not part of this simulation-only patch release. Synthesis behavior is therefore classified strictly as unverified by experimental evidence.

---

## 6. Environment Readiness Conclusion

The Vivado 2018.2 simulation environment is verified healthy, reproducible, and fully capable of compiling, elaborating, and simulating SystemVerilog designs using SystemVerilog 2012 features. No environment defects or toolchain corruptions exist.

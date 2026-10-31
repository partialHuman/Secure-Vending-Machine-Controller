# scripts/

## Prerequisites

- **Xilinx Vivado 2018.2** (or compatible XSIM installation) with the Vivado `bin` directory on `PATH` (e.g., `D:\Xilinx\Vivado\2018.2\bin`).
- Compatible with Tcl 8.5+ as embedded in Vivado 2018.2.

## Running the Regression

### Standard Run

Execute from any directory:

```bash
vivado -mode batch -source scripts/run_regression.tcl
```

(or `tclsh scripts/run_regression.tcl` when Vivado tools are on `PATH`).

### Strict Manifest Enforcement (Recommended for Releases)

Enforce that every selected testbench has an exact match in `scripts/expected_checks.txt`:

```bash
SVM_REQUIRE_MANIFEST=1 vivado -mode batch -source scripts/run_regression.tcl
```

In PowerShell:
```powershell
$env:SVM_REQUIRE_MANIFEST = "1"
vivado -mode batch -source scripts/run_regression.tcl
```

Expected result across the full suite: **497/497 checks passed**.

## Flow Description

1. Compiles all RTL modules (`transaction_pkg.sv` first, including `crc8.sv`, managers, controller, and top).
2. For each testbench (`tb_mixed_payment`, `tb_coin_only`, `tb_card_only`, `tb_handshake_security`):
   - Compiles testbench with `xvlog -sv`.
   - Elaborates simulation snapshot with `xelab -debug typical`.
   - Simulates snapshot with `xsim -runall`.
3. Validates execution through strict result parsing and check-count manifest gating. Exits `0` only if all testbenches pass.

## Result Marker Format & Verification Gating

Each testbench must emit exactly one formatted result line at the end of simulation:

```text
SVM_TB_RESULT: PASS total=<count> passed=<count> failed=0 tb_errors=0
```

The runner enforces strict gating:
- **Simulator Exit Code:** Non-zero exit status from `xsim` immediately forces test failure regardless of log content.
- **Marker Validation:** The log must contain exactly one valid result marker. Duplicate, malformed, contradictory, prefixed, or suffixed markers force a `FAIL`.
- **Count Arithmetic:** `total` must equal `passed + failed` and be positive.
- **Manifest Check:** If `SVM_REQUIRE_MANIFEST=1` (or if an expected count is defined in `expected_checks.txt`), the observed `total` must match the manifest count exactly. Check loss or inflation forces a `FAIL`.

## Environment Variables

| Variable | Description |
|---|---|
| `SVM_TBS="tb_mixed_payment tb_coin_only"` | Run only a subset of testbenches |
| `SVM_REQUIRE_MANIFEST=1` | Require every selected testbench to be in `expected_checks.txt` and match its check count |
| `SVM_STRICT_KL=1` | Pass `+STRICT_KL` runtime plusarg: observed known limitations (KL-xxx) fail the simulation |
| `SVM_UPDATE_MANIFEST=1` | After an all-PASS run, update `expected_checks.txt` with observed counts (review diff before commit) |

## Expected Checks Manifest (`expected_checks.txt`)

Format: `<testbench_name> <expected_count>`.

```text
tb_card_only 102
tb_coin_only 102
tb_handshake_security 220
tb_mixed_payment 73
```

- Total suite checks: **497 checks**.
- Used as a hard regression gate to prevent silent test omissions or assertion bypasses.

## Outputs (`build/`, git-ignored)

| Path | Description |
|---|---|
| `build/logs/` | Individual tool execution logs (`compile_rtl.log`, `<tb>_xvlog.log`, `<tb>_xelab.log`, `<tb>_xsim.log`) |
| `build/reports/<tb>/` | Testbench-generated reports (CSV transaction logs, HTML reports) |
| `build/PROVENANCE.txt` | Environment provenance: timestamp, OS details, Git commit hash, working-tree dirty state, and `xsim -version` |
| `build/regression-summary.txt` | Final console summary report including observed `SVM_KNOWN_LIMITATION` IDs |

## Unit Testing Runner Procedures (`::SVM_ONLY_PROCS`)

The runner exports its core validation routines (`load_manifest` and `parse_tb_result`) for headless testing without launching full Vivado simulations. Setting `::SVM_ONLY_PROCS=1` before sourcing `scripts/run_regression.tcl` loads the procedures and returns immediately:

```tcl
set ::SVM_ONLY_PROCS 1
source scripts/run_regression.tcl

# Test load_manifest
set res [load_manifest "scripts/expected_checks.txt" 1 {tb_coin_only tb_card_only tb_mixed_payment tb_handshake_security} {tb_coin_only}]
# Returns: [list OK "" {tb_card_only 102 tb_coin_only 102 tb_handshake_security 220 tb_mixed_payment 73}]

# Test parse_tb_result
set parse [parse_tb_result 0 "SVM_TB_RESULT: PASS total=102 passed=102 failed=0 tb_errors=0" 102 1]
# Returns: [list PASS "SVM_TB_RESULT: PASS total=102 passed=102 failed=0 tb_errors=0" 102]
```

## Legacy Scripts

`compile.tcl`, `simulate.tcl`, and `run_all.tcl` are superseded legacy scripts preserved in `scripts/` for historical continuity. They are directory-dependent and lack manifest and process exit-code validation. New workflows should exclusively use `scripts/run_regression.tcl`.

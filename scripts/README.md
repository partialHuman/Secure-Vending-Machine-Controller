# Simulation Scripts

## compile.tcl
Compiles all RTL and testbench files.

## simulate.tcl
Elaborates and runs the simulation.

## run_all.tcl
Runs the complete flow:
- Compile
- Elaborate
- Simulate
- Generate reports

# How to Run

```bash
vivado -mode batch -source scripts/run_regression.tcl
```

Compiles all RTL (including `crc8.sv`), then compiles/elaborates/runs each testbench
(`tb_mixed_payment`, `tb_coin_only`, `tb_card_only`), and exits non-zero unless every
testbench prints `SVM_TB_RESULT: PASS`. Logs and reports are written under `build/`.
Select testbenches with `SVM_TBS="tb_mixed_payment"`.

`compile.tcl`, `simulate.tcl`, `run_all.tcl` are the legacy flow and must be run from the
`scripts/` directory.

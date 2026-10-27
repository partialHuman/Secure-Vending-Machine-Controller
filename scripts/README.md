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

From the Vivado Tcl Console:
```
cd scripts
source run_all.tcl
```
or from the terminal:
```
vivado -mode tcl -source scripts/run_all.tcl
```
---
# Expected Output
```
=========================================
Secure Vending Machine Verification
=========================================

Compiling RTL...
✓ transaction_pkg.sv
✓ payment_interface.sv
✓ payment_arbiter.sv
✓ ...
✓ tb_mixed_payment.sv

Compilation Complete

Launching Simulation...

Running...

44 / 44 Tests Passed

CSV Reports Generated
HTML Report Generated
Simulation Log Generated

Simulation Finished

=========================================
Verification Complete
=========================================
```

# Simulation Commands & Procedures

## 1. Full Regression Execution (Default Mode)

```powershell
$env:SVM_REQUIRE_MANIFEST="1"
vivado -mode batch -source scripts/run_regression.tcl
```

Individual testbench compilation and simulation:

```powershell
# Compile RTL and Testbench
xvlog -sv rtl/transaction_pkg.sv rtl/crc8.sv rtl/*.sv tb/<testbench>.sv

# Elaborate Snapshot
xelab -debug typical -top <testbench> -snapshot <testbench>_snap

# Simulate
xsim <testbench>_snap -R
```

## 2. Strict Mode Execution (+STRICT_KL)

```powershell
$env:SVM_STRICT_KL="1"
vivado -mode batch -source scripts/run_regression.tcl
```

Or via direct xsim argument:

```powershell
xsim <testbench>_snap -R -testplusarg STRICT_KL
```

## 3. Negative Elaboration Tests

Validates compilation-time parameter bounds in `tb/tb_product_count.sv`:

```powershell
# Sizing parameter PRODUCT_COUNT = 0 (Must reject with VRFC 10-2063)
xelab -top tb_product_count -generic_top "PRODUCT_COUNT=0" -snapshot snap_p0

# Sizing parameter PRODUCT_COUNT = 33 (Must reject with VRFC 10-2063)
xelab -top tb_product_count -generic_top "PRODUCT_COUNT=33" -snapshot snap_p33
```

# Tool probes A–E (run BEFORE Phase 2)

Purpose: decide decision **D-102** (how an illegal `PRODUCT_COUNT` is rejected) and confirm the language features the plan relies on on **your Vivado 2018.2**. I could not run any of this; these files are untested by me.

From this directory (Vivado `bin` on `PATH`):

```bash
xvlog -sv probe_a_elab_error.sv probe_b_undefined_module.sv probe_c_runtime_fatal.sv probe_d_param_features.sv probe_e_depth_and_functions.sv

# A: elaboration-time $error
xelab probe_a_ok  -s pa_ok  ; echo "A ok  exit=$?"      # expect 0
xelab probe_a_bad -s pa_bad ; echo "A bad exit=$?"      # want non-zero + the PROBE_A text

# B: undefined module in unselected generate branch
xelab probe_b_ok  -s pb_ok  ; echo "B ok  exit=$?"      # expect 0  (if non-zero, mechanism B is unusable)
xelab probe_b_bad -s pb_bad ; echo "B bad exit=$?"      # want non-zero + module-not-found text

# C: runtime $fatal
xelab probe_c_ok  -s pc_ok  && xsim pc_ok  -runall ; echo "C ok  exit=$?"   # expect PROBE_C_OK
xelab probe_c_bad -s pc_bad && xsim pc_bad -runall ; echo "C bad exit=$?"   # must NOT print PROBE_C_BAD_SURVIVED

# D: language features
xelab probe_d_tb -s pd && xsim pd -runall
#   expect: PROBE_D dut: PC=8 MAX=32 rd(out-of-range)=0   and   PROBE_D tb reads dut.PC=8 (expect 8)

# E: array depth / constant function / hierarchical localparam
xelab probe_e_tb -s pe && xsim pe -runall
#   expect: PROBE_E1 size=8, bits=64; PROBE_E2 oob read isunknown=1, last valid=20;
#           PROBE_E3 dut.DEPTH=8; PROBE_E4 1 32 5.  Comment out any line that fails to compile and re-run;
#           report WHICH lines failed.
```

**Please send back, for every command:** the **stage** that produced the message (`xvlog`, `xelab` or `xsim`), the exit code, and the exact diagnostic text. A non-zero exit alone is not enough: the plan distinguishes expected elaboration failure, expected simulation failure and unexpected compile errors by stage and text.

Also send `xsim -version`.

Interpretation:

| Result | Decision |
|---|---|
| A-ok exit 0 **and** A-bad non-zero with the `PROBE_A` message | use mechanism 1 (`generate $error`) |
| A unsupported or A-ok non-zero, B-ok exit 0 and B-bad non-zero | use mechanism 2 (undefined module) |
| A and B both unusable | mechanism 3 (runtime `$fatal`) and the negative tests become simulation-time tests |
| D not as expected | tell me which line; the plan's parameter style needs adjusting |
| E2 prints `isunknown=1` | actual array depth is provable by an out-of-range hierarchical read (plan §6.4 primary method) |
| E2 fails, E1 works | use `$size`/`$bits` for the depth check |
| E1 and E2 both fail | depth is declared *unproven by simulation*; only the mutation check covers it |
| E4 fails | duplicate the clamp ternary in the two modules instead of a package function |

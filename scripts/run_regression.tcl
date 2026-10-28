# ============================================================================
# One-command regression for Secure-Vending-Machine-Controller
#
#   vivado -mode batch -source scripts/run_regression.tcl
#   (or:   tclsh scripts/run_regression.tcl      with Vivado bin dir on PATH)
#
# Optional:  SVM_TBS="tb_mixed_payment tb_coin_only"   (environment variable)
#
# - Works from any current directory (paths resolved from this script).
# - All generated files go to <repo>/build/ (git-ignored); reports to
#   <repo>/build/reports/<tb>/ so checked-in reports are never overwritten.
# - Exit status is 0 only if every testbench printed "SVM_TB_RESULT: PASS".
#   (The xsim process exit code is NOT relied upon.)
#
# NOTE: written for Vivado XSIM; not executed by the author of this patch.
# ============================================================================
set script_dir [file dirname [file normalize [info script]]]
set root       [file dirname $script_dir]
set build      [file join $root build]
file mkdir $build
cd $build

set rtl_files {
    transaction_pkg.sv crc8.sv payment_interface.sv payment_arbiter.sv
    security_engine.sv timeout_controller.sv balance_manager.sv
    inventory_manager.sv transaction_controller.sv response_generator.sv top.sv
}
if {[info exists ::env(SVM_TBS)]} { set tbs $::env(SVM_TBS) } else {
    set tbs {tb_mixed_payment tb_coin_only tb_card_only tb_handshake_security}
}

# Run an external command, merge stdout+stderr into <tag>.log.
# Returns the process exit status (0 = ok).
proc run_step {tag cmd} {
    puts ">> $cmd"
    set rc [catch {exec {*}$cmd >& "${tag}.log"} msg opts]
    if {$rc} {
        set ec [dict get $opts -errorcode]
        if {[lindex $ec 0] eq "CHILDSTATUS"} { return [lindex $ec 2] }
        puts "   launch failed: $msg"
        return 127
    }
    return 0
}

set failed {}
set summary {}

# ---- 1. compile RTL once --------------------------------------------------
set cmd [list xvlog -sv]
foreach f $rtl_files { lappend cmd [file join $root rtl $f] }
if {[run_step compile_rtl $cmd] != 0} {
    puts "FAIL: RTL compilation (see build/compile_rtl.log)"
    exit 1
}

# ---- 2. per-testbench: compile, elaborate, run, check marker ----------------
foreach tb $tbs {
    set repdir [file join $build reports $tb]
    file mkdir $repdir
    set status FAIL
    if {[run_step ${tb}_xvlog [list xvlog -sv [file join $root tb $tb.sv]]] == 0 &&
        [run_step ${tb}_xelab [list xelab $tb -debug typical -s ${tb}_snap]] == 0} {
        run_step ${tb}_xsim [list xsim ${tb}_snap -runall -testplusarg REPORT_DIR=$repdir]
        set fh [open ${tb}_xsim.log r]; set log [read $fh]; close $fh
        if {[regexp {SVM_TB_RESULT: PASS[^\n]*} $log line]} {
            set status PASS
        } elseif {[regexp {SVM_TB_RESULT: FAIL[^\n]*} $log line]} {
            set status FAIL
        } else {
            set line "no SVM_TB_RESULT marker found (hang, crash or old testbench)"
        }
    } else {
        set line "compile/elaborate error (see build/${tb}_*.log)"
    }
    lappend summary [format "%-18s %-5s %s" $tb $status $line]
    if {$status ne "PASS"} { lappend failed $tb }
}

puts "\n================ REGRESSION SUMMARY ================"
foreach l $summary { puts $l }
puts "===================================================="
if {[llength $failed]} { puts "RESULT: FAIL ([join $failed {, }])"; exit 1 }
puts "RESULT: PASS"
exit 0

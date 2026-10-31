# ============================================================================
# One-command regression for Secure-Vending-Machine-Controller   (v1.0.2)
#
#   vivado -mode batch -source scripts/run_regression.tcl
#   (or:   tclsh scripts/run_regression.tcl      with the Vivado bin dir on PATH)
#
# Environment variables (all optional):
#   SVM_TBS="tb_mixed_payment tb_coin_only"   run only these testbenches
#   SVM_STRICT_KL=1        pass +STRICT_KL: documented known limitations (KL-xxx)
#                          then FAIL the run instead of only being reported
#   SVM_REQUIRE_MANIFEST=1 a testbench with no entry in expected_checks.txt FAILS
#   SVM_UPDATE_MANIFEST=1  after an all-PASS run, rewrite expected_checks.txt with
#                          the observed check counts (review the diff before commit)
#
# - Works from any current directory (paths are resolved from this script).
# - Everything generated goes to <repo>/build/ (git-ignored):
#       build/logs/                 one log per tool invocation
#       build/reports/<tb>/         CSV/HTML/log reports written by the testbench
#       build/PROVENANCE.txt        date, OS, git commit, xsim version
#       build/regression-summary.txt
# - Exit status is 0 only if every testbench printed "SVM_TB_RESULT: PASS" AND its
#   check count equals the value recorded in scripts/expected_checks.txt.
#   The xsim process exit code is strictly verified.
#
# Written for Vivado XSIM (Tcl 8.5 syntax only).
# ============================================================================
set script_dir [file dirname [file normalize [info script]]]
set root       [file dirname $script_dir]
set build      [file join $root build]
set logdir     [file join $build logs]
file mkdir $build
file mkdir $logdir
cd $build

set rtl_files {
    transaction_pkg.sv crc8.sv payment_interface.sv payment_arbiter.sv
    security_engine.sv timeout_controller.sv balance_manager.sv
    inventory_manager.sv transaction_controller.sv response_generator.sv top.sv
}
set valid_tbs {tb_mixed_payment tb_coin_only tb_card_only tb_handshake_security}
if {[info exists ::env(SVM_TBS)]} {
    set tbs $::env(SVM_TBS)
} else {
    set tbs $valid_tbs
}

# ---- helpers ---------------------------------------------------------------
# Run an external command, merge stdout+stderr into build/logs/<tag>.log.
# Returns the process exit status (0 = ok, 127 = could not launch).
proc run_step {tag cmd} {
    global logdir
    puts ">> $cmd"
    set rc [catch {exec {*}$cmd >& [file join $logdir "${tag}.log"]} msg opts]
    if {$rc} {
        set ec [dict get $opts -errorcode]
        if {[lindex $ec 0] eq "CHILDSTATUS"} { return [lindex $ec 2] }
        puts "   launch failed: $msg"
        return 127
    }
    return 0
}

# First line of the output of a command, or a note if it could not be run.
proc first_line {cmd} {
    catch {exec {*}$cmd} out
    return [lindex [split [string trim $out] "\n"] 0]
}

# Load and validate the manifest file (expected_checks.txt).
# Returns a 3-element list: [list status error_msg name_count_list]
proc load_manifest {manifest_file require_manifest valid_tbs selected_tbs} {
    if {![file exists $manifest_file]} {
        if {$require_manifest} {
            return [list FAIL "manifest file not found: $manifest_file" {}]
        }
        return [list OK "" {}]
    }
    if {[catch {open $manifest_file r} fh]} {
        return [list FAIL "cannot open manifest file '$manifest_file': $fh" {}]
    }
    if {[catch {read $fh} mtext]} {
        catch {close $fh}
        return [list FAIL "cannot read manifest file '$manifest_file': $mtext" {}]
    }
    catch {close $fh}

    set entries {}
    set seen {}
    set line_no 0
    foreach mline [split $mtext "\n"] {
        incr line_no
        set mline [string trim $mline]
        if {$mline eq "" || [string index $mline 0] eq "#"} { continue }
        if {![regexp {^([a-zA-Z0-9_]+)\s+([0-9]+)$} $mline -> name count]} {
            return [list FAIL "malformed entry at line $line_no in manifest: '$mline'" {}]
        }
        if {$count <= 0} {
            return [list FAIL "invalid zero or negative expected count ($count) at line $line_no in manifest for '$name'" {}]
        }
        if {[llength $valid_tbs] > 0 && [lsearch -exact $valid_tbs $name] < 0} {
            return [list FAIL "unknown testbench '$name' in manifest at line $line_no (valid: [join $valid_tbs {, }])" {}]
        }
        if {[lsearch -exact $seen $name] >= 0} {
            return [list FAIL "duplicate entry in manifest for testbench '$name' at line $line_no" {}]
        }
        lappend seen $name
        lappend entries $name $count
    }

    if {$require_manifest} {
        if {[llength $seen] == 0} {
            return [list FAIL "manifest file is empty but strict manifest checking is required" {}]
        }
        foreach tb $selected_tbs {
            if {[lsearch -exact $seen $tb] < 0} {
                return [list FAIL "missing expected check count in manifest for selected testbench '$tb'" {}]
            }
        }
    }

    return [list OK "" $entries]
}

# Parse and validate the simulation log and process exit status for a testbench.
# Returns a 3-element list: [list status summary_line observed_count]
proc parse_tb_result {sim_rc log expected_count require_manifest} {
    set status FAIL
    set line ""
    set observed_count -1

    set marker_lines {}
    foreach l [split $log "\n"] {
        set l [string trim $l]
        if {[string match "*SVM_TB_RESULT*" $l]} {
            lappend marker_lines $l
        }
    }

    if {[llength $marker_lines] == 0} {
        set line "no SVM_TB_RESULT marker found (hang, crash or old testbench)"
    } elseif {[llength $marker_lines] > 1} {
        set line "duplicate or contradictory result markers found ([llength $marker_lines] markers)"
    } else {
        set marker [lindex $marker_lines 0]
        if {![regexp {^SVM_TB_RESULT:\s+(PASS|FAIL)\s+total=([0-9]+)\s+passed=([0-9]+)\s+failed=([0-9]+)\s+tb_errors=([0-9]+)$} $marker -> tb_verdict total passed failed_cnt tb_errors]} {
            set line "malformed SVM_TB_RESULT marker: $marker"
        } elseif {$total <= 0 || ($passed + $failed_cnt) != $total} {
            set line "malformed check counts in marker: total=$total passed=$passed failed=$failed_cnt (total != passed+failed or total <= 0)"
        } elseif {$tb_verdict eq "PASS"} {
            if {$failed_cnt != 0 || $tb_errors != 0 || $passed != $total} {
                set line "malformed PASS marker: passed=$passed failed=$failed_cnt tb_errors=$tb_errors"
            } else {
                set status PASS
                set line $marker
                set observed_count $total
                if {$expected_count ne ""} {
                    if {$expected_count != $total} {
                        set status FAIL
                        append line " | check count $total != expected $expected_count (scripts/expected_checks.txt)"
                    }
                } elseif {$require_manifest} {
                    set status FAIL
                    append line " | no expected check count recorded"
                } else {
                    append line " | WARNING: no expected count recorded (run once with SVM_UPDATE_MANIFEST=1)"
                }
            }
        } else {
            set line $marker
        }
    }

    if {$sim_rc != 0} {
        set status FAIL
        set observed_count -1
        if {$line eq ""} {
            set line "simulator process exited with code $sim_rc"
        } else {
            append line " | simulator process exited with code $sim_rc"
        }
    }

    return [list $status $line $observed_count]
}

# Allow external unit-test scripts to source procs only
if {[info exists ::SVM_ONLY_PROCS] && $::SVM_ONLY_PROCS} { return }

# ---- provenance -------------------------------------------------------------
set pf [open [file join $build PROVENANCE.txt] w]
puts $pf "date:        [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}]"
if {$::tcl_platform(platform) eq "windows"} {
    if {![catch {exec powershell -NoProfile -Command "(Get-CimInstance Win32_OperatingSystem).Caption + ' (' + (Get-CimInstance Win32_OperatingSystem).OSArchitecture + ')'"} win_os]} {
        puts $pf "os:          [string trim $win_os]"
    } elseif {![catch {exec cmd.exe /c ver} win_ver]} {
        puts $pf "os:          [string trim $win_ver]"
    } else {
        puts $pf "os:          Windows (64-bit)"
    }
} else {
    puts $pf "os:          [first_line [list uname -srm]]"
}
puts $pf "tcl:         [info patchlevel]"
puts $pf "git commit:  [first_line [list git -C $root rev-parse HEAD]]"
puts $pf "git status:  [first_line [list git -C $root status --short]]"
puts $pf "xsim:        [first_line [list xsim -version]]"
puts $pf "testbenches: $tbs"
close $pf

# ---- expected check counts (scripts/expected_checks.txt) --------------------
set manifest_file [file join $script_dir expected_checks.txt]
set req_manifest  [expr {[info exists ::env(SVM_REQUIRE_MANIFEST)] && $::env(SVM_REQUIRE_MANIFEST) eq "1"}]
array set expected {}

set mres [load_manifest $manifest_file $req_manifest $valid_tbs $tbs]
if {[lindex $mres 0] ne "OK"} {
    puts "FAIL: manifest validation failed: [lindex $mres 1]"
    exit 1
}
array set expected [lindex $mres 2]

set failed  {}
set summary {}
array set observed {}

# ---- 1. compile RTL once ----------------------------------------------------
set cmd [list xvlog -sv]
foreach f $rtl_files { lappend cmd [file join $root rtl $f] }
if {[run_step compile_rtl $cmd] != 0} {
    puts "FAIL: RTL compilation (see build/logs/compile_rtl.log)"
    exit 1
}

# ---- 2. per-testbench: compile, elaborate, run, check marker and count -------
foreach tb $tbs {
    set repdir [file join $build reports $tb]
    file mkdir $repdir
    set status FAIL
    set kls {}
    if {[run_step ${tb}_xvlog [list xvlog -sv [file join $root tb $tb.sv]]] == 0 &&
        [run_step ${tb}_xelab [list xelab $tb -debug typical -s ${tb}_snap]] == 0} {
        set xcmd [list xsim ${tb}_snap -runall -testplusarg REPORT_DIR=$repdir]
        if {[info exists ::env(SVM_STRICT_KL)]} { lappend xcmd -testplusarg STRICT_KL }
        set sim_rc [run_step ${tb}_xsim $xcmd]
        set logfile [file join $logdir ${tb}_xsim.log]
        if {![file exists $logfile]} {
            set line "simulation log missing: ${tb}_xsim.log"
            set status FAIL
        } else {
            set fh [open $logfile r]
            set log [read $fh]
            close $fh
            set exp_cnt ""
            if {[info exists expected($tb)]} { set exp_cnt $expected($tb) }
            set parse_res [parse_tb_result $sim_rc $log $exp_cnt $req_manifest]
            set status [lindex $parse_res 0]
            set line   [lindex $parse_res 1]
            set obs    [lindex $parse_res 2]
            if {$status eq "PASS" && $obs > 0} {
                set observed($tb) $obs
            }
            foreach {m id} [regexp -all -inline {SVM_KNOWN_LIMITATION: (KL-[0-9]+)} $log] { lappend kls $id }
            set kls [lsort -unique $kls]
        }
    } else {
        set line "compile/elaborate error (see build/logs/${tb}_*.log)"
    }
    if {[llength $kls]} { append line " | known limitations observed: [join $kls {, }]" }
    lappend summary [format "%-22s %-5s %s" $tb $status $line]
    if {$status ne "PASS"} { lappend failed $tb }
}

# ---- 3. summary ---------------------------------------------------------------
set out "================ REGRESSION SUMMARY ================\n"
foreach l $summary { append out "$l\n" }
append out "====================================================\n"
if {[llength $failed]} {
    append out "RESULT: FAIL ([join $failed {, }])\n"
} else {
    append out "RESULT: PASS\n"
}
puts "\n$out"
set sf [open [file join $build regression-summary.txt] w]
puts -nonewline $sf $out
close $sf

# ---- 4. optionally record observed counts -----------------------------------
if {[info exists ::env(SVM_UPDATE_MANIFEST)]} {
    if {[llength $failed]} {
        puts "NOTE: expected_checks.txt NOT updated because the run failed."
    } else {
        set mf [open $manifest_file w]
        puts $mf "# Expected check counts per testbench (the 'total=' value of SVM_TB_RESULT)."
        puts $mf "# Regenerate with:  SVM_UPDATE_MANIFEST=1 vivado -mode batch -source scripts/run_regression.tcl"
        puts $mf "# Review the diff before committing: a changed count means tests were added or removed."
        foreach name [lsort [array names observed]] { puts $mf "$name $observed($name)" }
        close $mf
        puts "expected_checks.txt updated."
    }
}

if {[llength $failed]} { exit 1 }
exit 0

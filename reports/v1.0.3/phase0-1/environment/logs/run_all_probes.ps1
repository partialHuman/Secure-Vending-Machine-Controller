$ErrorActionPreference = "Continue"
$reportsLogDir = "C:\Users\User\Documents\Projects\v1.0.3-phase0-1\reports\logs"
$probesDir = "C:\Users\User\Documents\Projects\v1.0.3-phase0-1\probes"
$vivadoBin = "D:\Xilinx\Vivado\2018.2\bin"
$env:PATH = "$vivadoBin;$env:PATH"

$logFile = Join-Path $reportsLogDir "probe_execution_raw.log"
"" | Out-File -FilePath $logFile -Encoding utf8

function Log-Output {
    param([string]$text)
    Write-Host $text
    $text | Out-File -FilePath $logFile -Append -Encoding utf8
}

Log-Output "================================================================================"
Log-Output "Secure Vending Machine Controller v1.0.3 - Vivado 2018.2 Compatibility Probes"
Log-Output "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss K')"
Log-Output "Host OS: $((Get-CimInstance Win32_OperatingSystem).Caption) $((Get-CimInstance Win32_OperatingSystem).OSArchitecture)"
Log-Output "Working Directory: $probesDir"
Log-Output "Vivado Bin Path: $vivadoBin"
Log-Output "================================================================================"
Log-Output ""

# 1. Environment Verification
Log-Output "--- SECTION 1: ENVIRONMENT VERIFICATION ---"

# vivado -version
$cmd = "vivado.bat -version"
Log-Output "Command: $cmd"
$start = Get-Date
$out = & vivado.bat -version 2>&1
$ec = $LASTEXITCODE
Log-Output "Exit Code: $ec"
Log-Output "Output:`n$($out -join "`n")"
Log-Output ""

# xvlog --version
$cmd = "xvlog.bat --version"
Log-Output "Command: $cmd"
$out = & xvlog.bat --version 2>&1
$ec = $LASTEXITCODE
Log-Output "Exit Code: $ec"
Log-Output "Output:`n$($out -join "`n")"
Log-Output ""

# xelab --version
$cmd = "xelab.bat --version"
Log-Output "Command: $cmd"
$out = & xelab.bat --version 2>&1
$ec = $LASTEXITCODE
Log-Output "Exit Code: $ec"
Log-Output "Output:`n$($out -join "`n")"
Log-Output ""

# xsim -version
$cmd = "xsim.bat -version"
Log-Output "Command: $cmd"
$out = & xsim.bat -version 2>&1
$ec = $LASTEXITCODE
Log-Output "Exit Code: $ec"
Log-Output "Output:`n$($out -join "`n")"
Log-Output ""

# Vivado Tcl Shell version verification
$tclScript = @"
puts "=== TCL VERSION OUTPUT ==="
puts [version]
puts "=== TCL EXEC XVLOG ==="
puts [exec xvlog --version]
puts "=== TCL EXEC XELAB ==="
puts [exec xelab --version]
puts "=== TCL EXEC XSIM -version (CATCH) ==="
set rc [catch {exec xsim -version 2>@1} msg opts]
puts "xsim -version catch result: `$rc, errorcode: [dict get `$opts -errorcode], msg: `$msg"
exit
"@
$tclPath = Join-Path $reportsLogDir "env_verify.tcl"
$tclScript | Out-File -FilePath $tclPath -Encoding ascii

$cmd = "vivado.bat -mode batch -nojournal -nolog -source $tclPath"
Log-Output "Command: $cmd"
$out = & vivado.bat -mode batch -nojournal -nolog -source $tclPath 2>&1
$ec = $LASTEXITCODE
Log-Output "Exit Code: $ec"
Log-Output "Output:`n$($out -join "`n")"
Log-Output ""

# Change to probes directory for execution
Set-Location -Path $probesDir

# 2. Compile All Probes
Log-Output "--- SECTION 2: COMPILATION OF ALL PROBE FILES ---"
$cmd = "xvlog -sv probe_a_elab_error.sv probe_b_undefined_module.sv probe_c_runtime_fatal.sv probe_d_param_features.sv probe_e_depth_and_functions.sv"
Log-Output "Command: $cmd"
$out = & xvlog -sv probe_a_elab_error.sv probe_b_undefined_module.sv probe_c_runtime_fatal.sv probe_d_param_features.sv probe_e_depth_and_functions.sv 2>&1
$ec = $LASTEXITCODE
Log-Output "Exit Code: $ec"
Log-Output "Output:`n$($out -join "`n")"
Log-Output ""

# 3. Probe A
Log-Output "--- SECTION 3: PROBE A ---"
$cmd = "xelab probe_a_ok -s pa_ok"
Log-Output "Command: $cmd"
$out = & xelab probe_a_ok -s pa_ok 2>&1
$ec = $LASTEXITCODE
Log-Output "Exit Code: $ec"
Log-Output "Output:`n$($out -join "`n")"
Log-Output ""

$cmd = "xelab probe_a_bad -s pa_bad"
Log-Output "Command: $cmd"
$out = & xelab probe_a_bad -s pa_bad 2>&1
$ec = $LASTEXITCODE
Log-Output "Exit Code: $ec"
Log-Output "Output:`n$($out -join "`n")"
Log-Output ""

$cmd = "xsim pa_bad -runall"
Log-Output "Command (diagnostic check on pa_bad simulation): $cmd"
$out = & xsim pa_bad -runall 2>&1
$ec = $LASTEXITCODE
Log-Output "Exit Code: $ec"
Log-Output "Output:`n$($out -join "`n")"
Log-Output ""

# 4. Probe B
Log-Output "--- SECTION 4: PROBE B ---"
$cmd = "xelab probe_b_ok -s pb_ok"
Log-Output "Command: $cmd"
$out = & xelab probe_b_ok -s pb_ok 2>&1
$ec = $LASTEXITCODE
Log-Output "Exit Code: $ec"
Log-Output "Output:`n$($out -join "`n")"
Log-Output ""

$cmd = "xelab probe_b_bad -s pb_bad"
Log-Output "Command: $cmd"
$out = & xelab probe_b_bad -s pb_bad 2>&1
$ec = $LASTEXITCODE
Log-Output "Exit Code: $ec"
Log-Output "Output:`n$($out -join "`n")"
Log-Output ""

# 5. Probe C
Log-Output "--- SECTION 5: PROBE C ---"
$cmd = "xelab probe_c_ok -s pc_ok"
Log-Output "Command: $cmd"
$out = & xelab probe_c_ok -s pc_ok 2>&1
$ec = $LASTEXITCODE
Log-Output "Exit Code: $ec"
Log-Output "Output:`n$($out -join "`n")"
Log-Output ""

$cmd = "xsim pc_ok -runall"
Log-Output "Command: $cmd"
$out = & xsim pc_ok -runall 2>&1
$ec = $LASTEXITCODE
Log-Output "Exit Code: $ec"
Log-Output "Output:`n$($out -join "`n")"
Log-Output ""

$cmd = "xelab probe_c_bad -s pc_bad"
Log-Output "Command: $cmd"
$out = & xelab probe_c_bad -s pc_bad 2>&1
$ec = $LASTEXITCODE
Log-Output "Exit Code: $ec"
Log-Output "Output:`n$($out -join "`n")"
Log-Output ""

$cmd = "xsim pc_bad -runall"
Log-Output "Command: $cmd"
$out = & xsim pc_bad -runall 2>&1
$ec = $LASTEXITCODE
Log-Output "Exit Code: $ec"
Log-Output "Output:`n$($out -join "`n")"
Log-Output ""

# 6. Probe D
Log-Output "--- SECTION 6: PROBE D ---"
$cmd = "xelab probe_d_tb -s pd"
Log-Output "Command: $cmd"
$out = & xelab probe_d_tb -s pd 2>&1
$ec = $LASTEXITCODE
Log-Output "Exit Code: $ec"
Log-Output "Output:`n$($out -join "`n")"
Log-Output ""

$cmd = "xsim pd -runall"
Log-Output "Command: $cmd"
$out = & xsim pd -runall 2>&1
$ec = $LASTEXITCODE
Log-Output "Exit Code: $ec"
Log-Output "Output:`n$($out -join "`n")"
Log-Output ""

# 7. Probe E
Log-Output "--- SECTION 7: PROBE E ---"
$cmd = "xelab probe_e_tb -s pe"
Log-Output "Command: $cmd"
$out = & xelab probe_e_tb -s pe 2>&1
$ec = $LASTEXITCODE
Log-Output "Exit Code: $ec"
Log-Output "Output:`n$($out -join "`n")"
Log-Output ""

$cmd = "xsim pe -runall"
Log-Output "Command: $cmd"
$out = & xsim pe -runall 2>&1
$ec = $LASTEXITCODE
Log-Output "Exit Code: $ec"
Log-Output "Output:`n$($out -join "`n")"
Log-Output ""

Log-Output "================================================================================"
Log-Output "Probe execution complete. Log written to $logFile"
Log-Output "================================================================================"

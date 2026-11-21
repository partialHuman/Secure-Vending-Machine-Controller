$ErrorActionPreference = "Continue"
$reportsFinalDir = "C:\Users\User\Documents\Projects\v1.0.3-phase0-1\reports\final"
$reportsFinalLogDir = "C:\Users\User\Documents\Projects\v1.0.3-phase0-1\reports\final\logs"
$simWorkDir = "C:\Users\User\Documents\Projects\v1.0.3-phase0-1\probes\extra\sim_n33"
$vivadoBin = "D:\Xilinx\Vivado\2018.2\bin"
$env:PATH = "$vivadoBin;$env:PATH"

$logFile1 = Join-Path $reportsFinalDir "N33_PROBE_RESULT.log"
$logFile2 = Join-Path $reportsFinalLogDir "n33_execution_raw.log"
"" | Out-File -FilePath $logFile1 -Encoding utf8
"" | Out-File -FilePath $logFile2 -Encoding utf8

function Log-Output {
    param([string]$text)
    Write-Host $text
    $text | Out-File -FilePath $logFile1 -Append -Encoding utf8
    $text | Out-File -FilePath $logFile2 -Append -Encoding utf8
}

Log-Output "================================================================================"
Log-Output "Secure Vending Machine Controller v1.0.3 - N=33 Probe Execution Log"
Log-Output "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss K')"
Log-Output "Toolchain: Xilinx Vivado 2018.2 / XSIM (SW Build 2258646)"
Log-Output "Host OS: $((Get-CimInstance Win32_OperatingSystem).Caption) $((Get-CimInstance Win32_OperatingSystem).OSArchitecture)"
Log-Output "Working Directory: $simWorkDir"
Log-Output "Source File: C:\Users\User\Documents\Projects\v1.0.3-phase0-1\probes\extra\probe_b_undefined_module_n33.sv"
Log-Output "================================================================================"
Log-Output ""

Set-Location -Path $simWorkDir

# Step 1: xvlog compilation
$cmd = "xvlog -sv ..\probe_b_undefined_module_n33.sv"
Log-Output "--- STEP 1: COMPILATION ---"
Log-Output "Command: $cmd"
$out = & xvlog -sv ..\probe_b_undefined_module_n33.sv 2>&1
$ec = $LASTEXITCODE
Log-Output "Exit Code: $ec"
Log-Output "Output:`n$($out -join "`n")"
Log-Output ""

# Step 2: xelab on probe_b_bad_33 (Mandatory Negative Test)
$cmd = "xelab probe_b_bad_33 -s pb_bad_33"
Log-Output "--- STEP 2: MANDATORY NEGATIVE TEST (N=33) ---"
Log-Output "Command: $cmd"
$out = & xelab probe_b_bad_33 -s pb_bad_33 2>&1
$ec = $LASTEXITCODE
Log-Output "Exit Code: $ec"
Log-Output "Output:`n$($out -join "`n")"
$snapshotExists = Test-Path -Path (Join-Path $simWorkDir "xsim.dir\pb_bad_33")
Log-Output "Snapshot pb_bad_33 Created: $snapshotExists"
Log-Output ""

# Step 3: xelab on probe_b_ok_32 (Optional Valid Boundary Control Test)
$cmd = "xelab probe_b_ok_32 -s pb_ok_32"
Log-Output "--- STEP 3: OPTIONAL VALID BOUNDARY CONTROL TEST (N=32) ---"
Log-Output "Command: $cmd"
$out = & xelab probe_b_ok_32 -s pb_ok_32 2>&1
$ec = $LASTEXITCODE
Log-Output "Exit Code: $ec"
Log-Output "Output:`n$($out -join "`n")"
$snapshotOkExists = Test-Path -Path (Join-Path $simWorkDir "xsim.dir\pb_ok_32")
Log-Output "Snapshot pb_ok_32 Created: $snapshotOkExists"
Log-Output ""

Log-Output "================================================================================"
Log-Output "N=33 Probe Execution Complete."
Log-Output "================================================================================"

puts "=== TCL VERSION OUTPUT ==="
puts [version]
puts "=== TCL EXEC XVLOG ==="
puts [exec xvlog --version]
puts "=== TCL EXEC XELAB ==="
puts [exec xelab --version]
puts "=== TCL EXEC XSIM -version (CATCH) ==="
set rc [catch {exec xsim -version 2>@1} msg opts]
puts "xsim -version catch result: $rc, errorcode: [dict get $opts -errorcode], msg: $msg"
exit

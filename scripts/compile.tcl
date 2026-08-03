puts "==========================================="
puts "Compiling RTL and Testbench"
puts "==========================================="

# Create work library
if {![file exists work]} {
    file mkdir work
}

# Compile Package
xvlog ../rtl/transaction_pkg.sv

# Compile RTL
xvlog ../rtl/payment_interface.sv
xvlog ../rtl/payment_arbiter.sv
xvlog ../rtl/security_engine.sv
xvlog ../rtl/timeout_controller.sv
xvlog ../rtl/balance_manager.sv
xvlog ../rtl/inventory_manager.sv
xvlog ../rtl/transaction_controller.sv
xvlog ../rtl/response_generator.sv
xvlog ../rtl/top.sv

# Compile Testbench
xvlog ../tb/tb_mixed_payment.sv

puts "Compilation Complete"
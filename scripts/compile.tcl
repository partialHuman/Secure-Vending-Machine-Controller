puts "==========================================="
puts "Compiling RTL and Testbenches"
puts "==========================================="

# Create work library
if {![file exists work]} {
    file mkdir work
}

# Compile Package
xvlog ../rtl/transaction_pkg.sv

# Compile RTL
xvlog ../rtl/crc8.sv
xvlog ../rtl/payment_interface.sv
xvlog ../rtl/payment_arbiter.sv
xvlog ../rtl/security_engine.sv
xvlog ../rtl/timeout_controller.sv
xvlog ../rtl/balance_manager.sv
xvlog ../rtl/inventory_manager.sv
xvlog ../rtl/transaction_controller.sv
xvlog ../rtl/response_generator.sv
xvlog ../rtl/top.sv

# Compile Testbenches
xvlog ../tb/tb_mixed_payment.sv
xvlog ../tb/tb_coin_only.sv
xvlog ../tb/tb_card_only.sv
xvlog ../tb/tb_handshake_security.sv

puts "Compilation Complete"

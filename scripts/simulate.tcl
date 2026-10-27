puts "Launching Simulation..."

xelab tb_mixed_payment -debug typical -s sim

xsim sim \
    -runall

puts "Simulation Finished"
quit
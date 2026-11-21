`timescale 1ns/1ps
// PROBE D: language features the plan relies on:
//   - package parameter derived with 2**W
//   - module parameter header defaulting to a package-scoped constant
//   - testbench reading a DUT parameter hierarchically (dut.PC)
//   - unpacked array whose depth is a parameter, indexed under a range guard
package probe_pkg;
    parameter int W   = 5;
    parameter int MAX = 2**W;
    parameter int DEF = 5;
endpackage

module probe_d_dut #(parameter int PC = probe_pkg::DEF) ();
    logic [7:0] mem [0:PC-1];
    logic [probe_pkg::W-1:0] id;
    logic [7:0] rd;
    wire id_valid = (id < PC);
    always_comb rd = id_valid ? mem[id] : 8'd0;
    initial begin
        for (int i = 0; i < PC; i = i + 1) mem[i] = i + 1;
        id = PC;                       // out of range on purpose (guarded)
        #1 $display("PROBE_D dut: PC=%0d MAX=%0d rd(out-of-range)=%0d", PC, probe_pkg::MAX, rd);
    end
endmodule

module probe_d_tb;
    probe_d_dut #(.PC(8)) dut ();
    initial begin
        #2 $display("PROBE_D tb reads dut.PC=%0d (expect 8)", dut.PC);
        $finish;
    end
endmodule

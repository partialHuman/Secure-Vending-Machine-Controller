`timescale 1ns/1ps
// PROBE E: how can the testbench prove the ACTUAL inventory array depth on Vivado 2018.2?
// Each line is independent; any that fail to compile should be reported (comment them out and re-run).
//   E1: $size / $bits on an unpacked array
//   E2: out-of-range hierarchical read of an unpacked array (expect X, no fatal)
//   E3: a localparam read hierarchically (dut.DEPTH)
//   E4: a constant function in a package used for a localparam and an array bound
package probe_e_pkg;
    parameter int MAXC = 32;
    function automatic int safe_count(input int c);
        if (c < 1) return 1;
        else if (c > MAXC) return MAXC;
        else return c;
    endfunction
endpackage

module probe_e_dut #(parameter int PC = 8);
    localparam int DEPTH = probe_e_pkg::safe_count(PC);     // E4
    logic [7:0] qty_mem [0:DEPTH-1];
    initial for (int i = 0; i < DEPTH; i = i + 1) qty_mem[i] = 8'd20;
endmodule

module probe_e_tb;
    probe_e_dut #(.PC(8)) dut ();
    initial begin
        #1;
        $display("PROBE_E1 size    = %0d (expect 8)", $size(dut.qty_mem));           // E1
        $display("PROBE_E1 bits    = %0d (expect 64)", $bits(dut.qty_mem));          // E1
        $display("PROBE_E2 oob read isunknown = %0b (expect 1)", $isunknown(dut.qty_mem[8]));   // E2
        $display("PROBE_E2 last valid = %0d (expect 20)", dut.qty_mem[7]);
        $display("PROBE_E3 dut.DEPTH = %0d (expect 8)", dut.DEPTH);                  // E3
        $display("PROBE_E4 safe_count(0)=%0d safe_count(33)=%0d safe_count(5)=%0d (expect 1 32 5)",
                 probe_e_pkg::safe_count(0), probe_e_pkg::safe_count(33), probe_e_pkg::safe_count(5));
        $finish;
    end
endmodule

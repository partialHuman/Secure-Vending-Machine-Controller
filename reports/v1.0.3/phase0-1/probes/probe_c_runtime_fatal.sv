`timescale 1ns/1ps
// PROBE C: simulation-time rejection with $fatal. The "bad" top must stop at time 0
// and must NOT print PROBE_C_BAD_SURVIVED.
module probe_c_core #(parameter int N = 5);
    initial if (N < 1 || N > 32) $fatal(1, "PROBE_C: N=%0d is outside 1..32", N);
endmodule

module probe_c_ok;
    probe_c_core #(.N(5)) u ();
    initial begin #10; $display("PROBE_C_OK"); $finish; end
endmodule

module probe_c_bad;
    probe_c_core #(.N(0)) u ();
    initial begin #10; $display("PROBE_C_BAD_SURVIVED"); $finish; end
endmodule

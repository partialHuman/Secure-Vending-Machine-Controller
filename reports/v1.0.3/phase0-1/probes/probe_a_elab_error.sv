`timescale 1ns/1ps
// PROBE A: does xelab (Vivado 2018.2) support an elaboration-time $error in a generate-if,
// and does it fail the elaboration of the "bad" top while accepting the "ok" top?
module probe_a_core #(parameter int N = 5);
    generate
        if (N < 1 || N > 32) begin : g_bad_count
            $error("PROBE_A: N=%0d is outside 1..32", N);
        end
    endgenerate
endmodule

module probe_a_ok;  probe_a_core #(.N(5)) u (); endmodule
module probe_a_bad; probe_a_core #(.N(0)) u (); endmodule

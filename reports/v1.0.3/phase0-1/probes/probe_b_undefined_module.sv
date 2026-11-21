`timescale 1ns/1ps
// PROBE B: portable rejection by instantiating a deliberately undefined module in the
// *unselected* generate branch. Must elaborate for N=5 and fail for N=0.
module probe_b_core #(parameter int N = 5);
    generate
        if (N < 1 || N > 32) begin : g_bad_count
            PRODUCT_COUNT_OUT_OF_RANGE_see_docs u_invalid ();
        end
    endgenerate
endmodule

module probe_b_ok;  probe_b_core #(.N(5)) u (); endmodule
module probe_b_bad; probe_b_core #(.N(0)) u (); endmodule

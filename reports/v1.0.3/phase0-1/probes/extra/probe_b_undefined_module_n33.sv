`timescale 1ns/1ps
// PROBE B (N=33 & N=32 boundary test):
// Validates rejection of upper out-of-range parameter N=33 and acceptance of boundary N=32.
// Uses an isolated module hierarchy to prevent collisions with probe_b_core.

module probe_b_n33_core #(parameter int N = 5);
    generate
        if (N < 1 || N > 32) begin : g_bad_count
            PRODUCT_COUNT_OUT_OF_RANGE_see_docs u_invalid ();
        end
    endgenerate
endmodule

// Mandatory negative test: N=33 (must fail elaboration with VRFC 10-2063)
module probe_b_bad_33;
    probe_b_n33_core #(.N(33)) u ();
endmodule

// Optional control test: boundary valid N=32 (must elaborate cleanly with exit code 0)
module probe_b_ok_32;
    probe_b_n33_core #(.N(32)) u ();
endmodule

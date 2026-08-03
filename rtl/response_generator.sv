`timescale 1ns/1ps

module response_generator
(
    input  logic clk,
    input  logic rst,

    input  logic dispense,
    input  logic refund,
    input  logic complete,

    input  logic [transaction_pkg::BALANCE_WIDTH-1:0] refund_amount,

    input  transaction_pkg::status_t status,
    input  transaction_pkg::error_t  error_code,

    output transaction_pkg::response_packet_t response,
    output logic response_valid
);

import transaction_pkg::*;

response_packet_t response_reg;

assign response = response_reg;

//----------------------------------------------------
// dispense/refund from transaction_controller are
// single-cycle pulses that occur one clock BEFORE
// complete (they also drive sub_en/refund_en on the
// resource managers, so their pulse timing can't
// change). Latch them here so the pulse survives
// until complete gates the response capture.
//----------------------------------------------------

logic dispense_latched;
logic refund_latched;

always_ff @(posedge clk)
begin

    if(rst)
    begin
        response_reg     <= '0;
        response_valid   <= 1'b0;

        dispense_latched <= 1'b0;
        refund_latched   <= 1'b0;
    end
    else
    begin

        response_valid <= 1'b0;

        if(dispense) dispense_latched <= 1'b1;
        if(refund)   refund_latched   <= 1'b1;

        if(complete)
        begin
            response_reg.status    <= status;
            response_reg.error     <= error_code;
            response_reg.dispense  <= dispense_latched;
            response_reg.refund    <= refund_latched ? refund_amount : '0;

            response_valid <= 1'b1;

            dispense_latched <= 1'b0;
            refund_latched   <= 1'b0;
        end

    end

end

endmodule
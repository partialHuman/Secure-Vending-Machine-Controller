`timescale 1ns/1ps

module payment_arbiter
(
    input  logic clk,
    input  logic rst,

    input  logic packet_valid,
    input  transaction_pkg::transaction_packet_t packet,

    output logic arbiter_ready,

    output transaction_pkg::transaction_packet_t out_packet,
    output logic out_valid,

    input logic out_ready
);

import transaction_pkg::*;

transaction_packet_t packet_reg;
logic valid_reg;

//--------------------------------------------------
// Input is ready whenever the buffer is empty,
// or the output is consuming the current packet.
//--------------------------------------------------

assign arbiter_ready = !valid_reg || out_ready;

//--------------------------------------------------
// Output
//--------------------------------------------------

assign out_packet = packet_reg;
assign out_valid  = valid_reg;

//--------------------------------------------------
// Sequential Logic
//--------------------------------------------------

always_ff @(posedge clk)
begin

    if (rst)
    begin
        packet_reg <= '0;
        valid_reg  <= 1'b0;
    end

    else
    begin

        case ({packet_valid && arbiter_ready, out_ready && valid_reg})

            //--------------------------------------------------
            // Load new packet only
            //--------------------------------------------------

            2'b10:
            begin
                packet_reg <= packet;
                valid_reg  <= 1'b1;
            end

            //--------------------------------------------------
            // Remove packet only
            //--------------------------------------------------

            2'b01:
            begin
                valid_reg <= 1'b0;
            end

            //--------------------------------------------------
            // Replace packet
            //--------------------------------------------------

            2'b11:
            begin
                packet_reg <= packet;
                valid_reg  <= 1'b1;
            end

            //--------------------------------------------------
            // Hold packet
            //--------------------------------------------------

            default:
            begin
                packet_reg <= packet_reg;
                valid_reg  <= valid_reg;
            end

        endcase

    end

end

endmodule
`timescale 1ns/1ps

import transaction_pkg::*;

module payment_interface
(
    input  logic clk,
    input  logic rst,

    //--------------------------------------------------
    // Input Request
    //--------------------------------------------------

    input  logic              request_valid,

    input  payment_request_t  request,

    //--------------------------------------------------
    // Handshake
    //--------------------------------------------------

    input  logic arbiter_ready,

    //--------------------------------------------------
    // Output Packet
    //--------------------------------------------------

    output logic packet_valid,

    output transaction_packet_t packet

);

logic [15:0] transaction_counter;

//------------------------------------------------------
// CRC Generation
//------------------------------------------------------
// CRC is computed over {payment_type, amount, product_id,
// next transaction_id} so that any corruption introduced
// after this point (arbiter buffering, bus glitches, etc.)
// can be detected by security_engine.
//------------------------------------------------------

logic [7:0] gen_crc;

crc8 #(
    .DATA_WIDTH(PAYMENT_WIDTH + BALANCE_WIDTH + PRODUCT_ID_WIDTH + TRANSACTION_WIDTH)
) u_crc_gen
(
    .data_in ({request.payment_type, request.amount, request.product_id, transaction_counter}),
    .crc_out (gen_crc)
);

//------------------------------------------------------
// Main Logic
//------------------------------------------------------

always_ff @(posedge clk)
begin

    if(rst)
    begin

        transaction_counter <= 16'd1;

        packet_valid <= 1'b0;

        packet <= '0;

    end

    else
    begin

        packet_valid <= 1'b0;

        //----------------------------------------------

        if(request_valid && arbiter_ready)
        begin

            packet.payment_type <= request.payment_type;

            packet.amount <= request.amount;

            packet.product_id <= request.product_id;

            packet.transaction_id <= transaction_counter;
            packet.crc <= gen_crc;

            transaction_counter <= transaction_counter + 1;

            packet_valid <= 1'b1;

        end

    end

end

endmodule
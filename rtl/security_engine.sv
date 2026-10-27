`timescale 1ns/1ps

module security_engine
(
    input  logic clk,
    input  logic rst,

    input  logic packet_valid,
    input  transaction_pkg::transaction_packet_t packet,

    output logic security_ok,
    output transaction_pkg::error_t security_error,

    // Pulses once for every packet processed, success or
    // reject - lets transaction_controller advance out of
    // IDLE regardless of outcome.
    output logic security_done,

    // Validated packet output
    output logic secure_valid,
    output transaction_pkg::transaction_packet_t secure_packet
);

import transaction_pkg::*;

//----------------------------------------------------
// Internal Registers
//----------------------------------------------------

logic [15:0] last_transaction_id;

logic security_ok_reg;
error_t security_error_reg;

//----------------------------------------------------
// CRC Verification
//----------------------------------------------------

logic [7:0] calculated_crc;

crc8 #(
    .DATA_WIDTH(PAYMENT_WIDTH + BALANCE_WIDTH + PRODUCT_ID_WIDTH + TRANSACTION_WIDTH)
) u_crc_check
(
    .data_in ({packet.payment_type, packet.amount, packet.product_id, packet.transaction_id}),
    .crc_out (calculated_crc)
);

//----------------------------------------------------
// Sequential Logic
//----------------------------------------------------

always_ff @(posedge clk)
begin

    if (rst)
    begin
        last_transaction_id <= 16'hFFFF;

        security_ok    <= 1'b0;
        security_error <= ERR_NONE;
        security_done  <= 1'b0;

        secure_valid   <= 1'b0;
        secure_packet  <= '0;
    end

    else
    begin

        //------------------------------------------------
        // Default Outputs
        //------------------------------------------------

        security_ok    <= 1'b0;
        security_error <= ERR_NONE;
        security_done  <= 1'b0;
        secure_valid   <= 1'b0;

        //------------------------------------------------
        // Process Incoming Packet
        //------------------------------------------------

        if(packet_valid)
        begin

            //------------------------------------------------
            // Pulses regardless of pass/fail so the FSM can
            // always advance out of IDLE for this packet.
            //------------------------------------------------

            security_done <= 1'b1;

            //------------------------------------------------
            // Save latest transaction ID
            //------------------------------------------------

            last_transaction_id <= packet.transaction_id;

            //------------------------------------------------
            // CRC Verification (highest priority - if the
            // packet is corrupted we cannot trust any other
            // field, including transaction_id)
            //------------------------------------------------

            if(packet.crc != calculated_crc)
            begin

                security_ok    <= 1'b0;
                security_error <= ERR_CRC;

            end

            //------------------------------------------------
            // Duplicate Transaction
            //------------------------------------------------

            else if(packet.transaction_id == last_transaction_id)
            begin

                security_ok    <= 1'b0;
                security_error <= ERR_DUPLICATE;

            end

            //------------------------------------------------
            // Invalid Product
            //------------------------------------------------

            else if(packet.product_id >= PRODUCT_COUNT)
            begin

                security_ok    <= 1'b0;
                security_error <= ERR_INVALID_PRODUCT;

            end

            //------------------------------------------------
            // Invalid Amount
            //------------------------------------------------

            else if(packet.amount == 16'd0)
            begin

                security_ok    <= 1'b0;
                security_error <= ERR_BALANCE;

            end

            //------------------------------------------------
            // Example Authentication Rule
            //------------------------------------------------

            else if((packet.payment_type == CARD) &&
                    (packet.amount > 16'd5000))
            begin

                security_ok    <= 1'b0;
                security_error <= ERR_AUTH;

            end

            //------------------------------------------------
            // Security Passed
            //------------------------------------------------

            else
            begin

                security_ok    <= 1'b1;
                security_error <= ERR_NONE;

                secure_valid   <= 1'b1;
                secure_packet  <= packet;

            end

        end

    end

end

endmodule
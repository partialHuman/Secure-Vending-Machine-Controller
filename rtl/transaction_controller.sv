`timescale 1ns/1ps

module transaction_controller
(
    input  logic clk,
    input  logic rst,

    //--------------------------------------------------
    // Secure Packet from Security Engine
    //--------------------------------------------------
    input  logic security_done,

    input  logic security_ok,
    input  transaction_pkg::error_t security_error,

    //--------------------------------------------------
    // Timeout Controller
    //--------------------------------------------------
    input  logic timeout,

    //--------------------------------------------------
    // Resource Status
    //--------------------------------------------------
    input  logic balance_ok,
    input  logic stock_ok,

    //--------------------------------------------------
    // Outputs
    //--------------------------------------------------
    output logic arbiter_ready,

    // High for the whole transaction (RECEIVE_PAYMENT
    // through COMPLETE). Drives balance_manager/
    // inventory_manager reads so their combinational
    // outputs (product_price, quantity, stock_ok, ...)
    // stay valid for as long as the FSM needs them,
    // instead of only for the single cycle secure_valid
    // used to pulse.
    output logic busy,

    output logic dispense,
    output logic refund,
    output logic complete,

    output transaction_pkg::status_t status,
    output transaction_pkg::error_t error_code
);

import transaction_pkg::*;

//-----------------------------------------------------
// FSM State
//-----------------------------------------------------

state_t current_state;
state_t next_state;

//-----------------------------------------------------
// Registered Outputs
//-----------------------------------------------------

logic dispense_reg;
logic refund_reg;
logic complete_reg;

status_t status_reg;
error_t  error_reg;

//-----------------------------------------------------
// Latched Security Decision
//-----------------------------------------------------
// security_ok/security_error from security_engine are
// single-cycle pulses valid only on the cycle
// security_done fires (while current_state is still
// IDLE). AUTHENTICATE runs several cycles later, so the
// decision must be captured here rather than re-read live.
//-----------------------------------------------------

logic   sec_ok_latched;
error_t sec_err_latched;

//-----------------------------------------------------
// State Register
//-----------------------------------------------------

always_ff @(posedge clk)
begin
    if (rst)
        current_state <= IDLE;
    else
        current_state <= next_state;
end

//-----------------------------------------------------
// Next-State Logic
//-----------------------------------------------------

always_comb
begin

    next_state = current_state;

    case(current_state)

        //-------------------------------------------------

        IDLE:
        begin
            if(security_done)
                next_state = RECEIVE_PAYMENT;
        end

        //-------------------------------------------------

        RECEIVE_PAYMENT:
        begin
            next_state = AUTHENTICATE;
        end

        //-------------------------------------------------

        AUTHENTICATE:
        begin

            if(timeout)
                next_state = COMPLETE;

            else if(!sec_ok_latched)
                next_state = COMPLETE;

            else
                next_state = CHECK_BALANCE;

        end

        //-------------------------------------------------

        CHECK_BALANCE:
        begin

            if(timeout)
                next_state = COMPLETE;

            else if(balance_ok)
                next_state = CHECK_INVENTORY;

            else
                next_state = REFUND;

        end

        //-------------------------------------------------

        CHECK_INVENTORY:
        begin

            if(timeout)
                next_state = COMPLETE;

            else if(stock_ok)
                next_state = DISPENSE;

            else
                next_state = REFUND;

        end

        //-------------------------------------------------

        DISPENSE:
            next_state = COMPLETE;

        //-------------------------------------------------

        REFUND:
            next_state = COMPLETE;

        //-------------------------------------------------

        COMPLETE:
            next_state = IDLE;

        //-------------------------------------------------

        default:
            next_state = IDLE;

    endcase

end

//-----------------------------------------------------
// Output Logic
//-----------------------------------------------------

always_ff @(posedge clk)
begin

    if(rst)
    begin

        dispense_reg <= 1'b0;
        refund_reg   <= 1'b0;
        complete_reg <= 1'b0;

        status_reg   <= STATUS_IDLE;
        error_reg    <= ERR_NONE;

        sec_ok_latched  <= 1'b0;
        sec_err_latched <= ERR_NONE;

    end
    //-------------------------------------------------
    // Highest Priority : Timeout
    //-------------------------------------------------

    else if(timeout)
    begin

        dispense_reg <= 1'b0;
        refund_reg   <= 1'b0;
        complete_reg <= 1'b1;

        status_reg   <= STATUS_TIMEOUT;
        error_reg    <= ERR_TIMEOUT;

    end

    else
    begin

        //-------------------------------------------------
        // Default pulse outputs
        //-------------------------------------------------

        dispense_reg <= 1'b0;
        refund_reg   <= 1'b0;
        complete_reg <= 1'b0;

        case(current_state)

            //-------------------------------------------------

            IDLE:
            begin

                status_reg <= STATUS_IDLE;
                error_reg  <= ERR_NONE;

                if(security_done)
                begin
                    sec_ok_latched  <= security_ok;
                    sec_err_latched <= security_error;
                end

            end

            //-------------------------------------------------

            RECEIVE_PAYMENT:
            begin

                status_reg <= STATUS_BUSY;

            end

            //-------------------------------------------------

            AUTHENTICATE:
            begin

                status_reg <= STATUS_BUSY;

                if(timeout)
                begin
                    status_reg <= STATUS_TIMEOUT;
                    error_reg  <= ERR_TIMEOUT;
                end

                else if(!sec_ok_latched)
                begin
                    status_reg <= STATUS_FAILED;
                    error_reg  <= sec_err_latched;
                end

            end

            //-------------------------------------------------

            CHECK_BALANCE:
            begin

                status_reg <= STATUS_BUSY;

                if(timeout)
                begin
                    status_reg <= STATUS_TIMEOUT;
                    error_reg  <= ERR_TIMEOUT;
                end

                else if(!balance_ok)
                begin
                    status_reg <= STATUS_FAILED;
                    error_reg  <= ERR_BALANCE;
                end

            end

            //-------------------------------------------------

            CHECK_INVENTORY:
            begin

                status_reg <= STATUS_BUSY;

                if(timeout)
                begin
                    status_reg <= STATUS_TIMEOUT;
                    error_reg  <= ERR_TIMEOUT;
                end

                else if(!stock_ok)
                begin
                    status_reg <= STATUS_FAILED;
                    error_reg  <= ERR_STOCK;
                end

            end

            //-------------------------------------------------

            DISPENSE:
            begin

                dispense_reg <= 1'b1;

                status_reg <= STATUS_SUCCESS;
                error_reg  <= ERR_NONE;

            end

            //-------------------------------------------------

            REFUND:
            begin

                refund_reg <= 1'b1;

                status_reg <= STATUS_FAILED;
                if(!balance_ok)
                    error_reg <= ERR_BALANCE;
                else if(!stock_ok)
                    error_reg <= ERR_STOCK;
                else
                    error_reg <= ERR_NONE;

            end

            //-------------------------------------------------

            COMPLETE:
            begin

                complete_reg <= 1'b1;

            end

        endcase

    end

end

//-----------------------------------------------------
// Outputs
//-----------------------------------------------------

assign dispense = dispense_reg;
assign refund   = refund_reg;
assign complete = complete_reg;

assign status     = status_reg;
assign error_code = error_reg;

//-----------------------------------------------------
// Busy (transaction in progress)
//-----------------------------------------------------

assign busy = (current_state != IDLE);

//-----------------------------------------------------
// Arbiter Ready
//-----------------------------------------------------

assign arbiter_ready = (current_state == IDLE);

endmodule
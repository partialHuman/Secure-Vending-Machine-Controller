`timescale 1ns/1ps

module top
(
    input logic clk,
    input logic rst,

    input logic request_valid,
    input transaction_pkg::payment_request_t request,

    output transaction_pkg::response_packet_t response,
    output logic response_valid,
    
     //==================================================
    // Debug Outputs
    //==================================================

    output transaction_pkg::transaction_packet_t debug_packet,
    output logic [transaction_pkg::BALANCE_WIDTH-1:0] debug_balance,
    output logic [transaction_pkg::BALANCE_WIDTH-1:0] debug_refund,
    output logic [transaction_pkg::PRICE_WIDTH-1:0] debug_price,
    output logic [transaction_pkg::INVENTORY_WIDTH-1:0] debug_quantity,
    output logic debug_security_ok,
    output logic debug_busy,
    output logic debug_dispense,
    output logic debug_complete
);

import transaction_pkg::*;

//==================================================
// Internal Signals
//==================================================

// Payment Interface
logic packet_valid;
transaction_packet_t packet;

// Arbiter
logic arbiter_ready;
logic out_valid;
transaction_packet_t out_packet;

// Security Engine
logic security_ok;
logic security_done;
logic secure_valid;
error_t security_error;
transaction_packet_t secure_packet;

// Timeout Controller
logic timeout;

// Balance Manager
logic add_en;
logic sub_en;
logic refund_en;
logic clear_en;

logic [transaction_pkg::BALANCE_WIDTH-1:0] current_balance;
logic [transaction_pkg::BALANCE_WIDTH-1:0] refund_amount;

// Inventory Manager
logic read_en;
logic purchase_en;

logic update_price;
logic update_qty;

logic [transaction_pkg::PRICE_WIDTH-1:0] product_price;
logic [transaction_pkg::INVENTORY_WIDTH-1:0] quantity;
logic low_stock;

// Transaction Controller
logic controller_ready;
logic busy;

logic dispense;
logic refund;
logic complete;

status_t status;
error_t error_code;
state_t debug_state;
// Resource Managers
logic balance_ok;
logic stock_ok;

//==================================================
// Payment Interface
//==================================================

payment_interface u_payment_interface
(
    .clk(clk),
    .rst(rst),

    .request(request),
    .request_valid(request_valid),

    .arbiter_ready(arbiter_ready),

    .packet(packet),
    .packet_valid(packet_valid)
);

//==================================================
// Arbiter
//==================================================

payment_arbiter u_payment_arbiter
(
    .clk(clk),
    .rst(rst),

    .packet_valid(packet_valid),
    .packet(packet),

    .arbiter_ready(arbiter_ready),

    .out_packet(out_packet),
    .out_valid(out_valid),

    .out_ready(controller_ready)
);

//==================================================
// Security Engine
//==================================================

security_engine u_security_engine
(
    .clk(clk),
    .rst(rst),

    .packet_valid(out_valid),
    .packet(out_packet),

    .security_ok(security_ok),
    .security_error(security_error),
    .security_done(security_done),

    .secure_valid(secure_valid),
    .secure_packet(secure_packet)
);

//==================================================
// Timeout Controller
//==================================================

timeout_controller u_timeout_controller
(
    .clk(clk),
    .rst(rst),

    .transaction_start(secure_valid),
    .transaction_done(complete),

    .timeout(timeout)
);

//--------------------------------------------------
// Balance Manager
//--------------------------------------------------

balance_manager u_balance_manager
(
    .clk(clk),
    .rst(rst),

    .add_en(add_en),
    .sub_en(sub_en),
    .refund_en(refund_en),
    .clear_en(clear_en),

    .amount_in(secure_packet.amount),

    .required_amount(product_price),

    .current_balance(current_balance),
    .refund_amount(refund_amount),

    .balance_ok(balance_ok),
    .overflow(),
    .underflow()
);

//--------------------------------------------------
// Inventory Manager
//--------------------------------------------------

inventory_manager u_inventory_manager
(
    .clk(clk),
    .rst(rst),

    .product_id(secure_packet.product_id),

    .read_en(read_en),
    .purchase_en(purchase_en),

    .update_price(update_price),
    .update_qty(update_qty),

    .new_price('0),
    .new_qty('0),

    .product_price(product_price),
    .quantity(quantity),

    .stock_available(),
    .stock_ok(stock_ok),
    .low_stock(low_stock)
);

//==================================================
// Transaction Controller
//==================================================

transaction_controller u_transaction_controller
(
    .clk(clk),
    .rst(rst),

    .security_done(security_done),

    .security_ok(security_ok),
    .security_error(security_error),
    .timeout(timeout),

    .balance_ok(balance_ok),
    .stock_ok(stock_ok),

    .arbiter_ready(controller_ready),
    .busy(busy),

    .dispense(dispense),
    .refund(refund),
    .complete(complete),

    .status(status),
    .error_code(error_code)
);

//==================================================
// Response Generator
//==================================================

response_generator u_response_generator
(
    .clk(clk),
    .rst(rst),

    .dispense(dispense),
    .refund(refund),
    .complete(complete),

    .refund_amount(refund_amount),

    .status(status),
    .error_code(error_code),

    .response(response),
    .response_valid(response_valid)
);

//--------------------------------------------------
// Manager Control Logic
//--------------------------------------------------

assign add_en      = secure_valid;
assign sub_en      = dispense;
assign refund_en   = refund;
assign clear_en    = complete;

assign read_en     = busy;
assign purchase_en = dispense;

assign update_price = 1'b0;
assign update_qty   = 1'b0;

//--------------------------------------------------
// Debug Connections
//--------------------------------------------------

assign debug_packet      = secure_packet;
assign debug_state       = u_transaction_controller.current_state;
assign debug_balance     = current_balance;
assign debug_refund      = refund_amount;
assign debug_price       = product_price;
assign debug_quantity    = quantity;
assign debug_security_ok = security_ok;
assign debug_busy        = busy;
assign debug_dispense    = dispense;
assign debug_complete    = complete;

endmodule
`timescale 1ns/1ps

module inventory_manager #(
    parameter int PRODUCT_COUNT = transaction_pkg::PRODUCT_COUNT_DEFAULT,
    parameter int PRICE_WIDTH   = 16,
    parameter int QTY_WIDTH     = 8
)
(
    input logic clk,
    input logic rst,

    //-------------------------------------------------
    // Product Selection
    //-------------------------------------------------

    input logic [transaction_pkg::PRODUCT_ID_WIDTH-1:0] product_id,

    //-------------------------------------------------
    // Control Signals
    //-------------------------------------------------

    input logic read_en,
    input logic purchase_en,

    input logic update_price,
    input logic update_qty,

    //-------------------------------------------------
    // Update Data
    //-------------------------------------------------

    input logic [PRICE_WIDTH-1:0] new_price,
    input logic [QTY_WIDTH-1:0]   new_qty,

    //-------------------------------------------------
    // Outputs
    //-------------------------------------------------

    output logic [PRICE_WIDTH-1:0] product_price,
    output logic [QTY_WIDTH-1:0]   quantity,

    output logic stock_available,
    output logic stock_ok,
    output logic low_stock
);

import transaction_pkg::*;

localparam int unsigned PC_SAFE = (PRODUCT_COUNT < 1) ? 1 :
                                  (PRODUCT_COUNT > transaction_pkg::PRODUCT_COUNT_MAX) ? transaction_pkg::PRODUCT_COUNT_MAX :
                                  PRODUCT_COUNT;

//=====================================================
// Memory
//=====================================================

logic [PRICE_WIDTH-1:0] price_mem [0:PC_SAFE-1];
logic [QTY_WIDTH-1:0]   qty_mem   [0:PC_SAFE-1];

integer i;

wire id_valid = (product_id < PC_SAFE);

//=====================================================
// Inventory Update
//=====================================================

always_ff @(posedge clk)
begin

    if(rst)
    begin

        for(i=0; i<PC_SAFE; i=i+1)
        begin
            price_mem[i] <= (i+1)*10;
            qty_mem[i]   <= 20;
        end

    end

    else if(id_valid)
    begin

        //--------------------------------------------
        // Update Product Price
        //--------------------------------------------

        if(update_price)
            price_mem[product_id] <= new_price;

        //--------------------------------------------
        // Update Quantity
        //--------------------------------------------

        if(update_qty)
            qty_mem[product_id] <= new_qty;

        //--------------------------------------------
        // Purchase Product
        //--------------------------------------------

        if(purchase_en && qty_mem[product_id] > 0)
            qty_mem[product_id] <= qty_mem[product_id] - 1;

    end

end

//=====================================================
// Read Logic
//=====================================================

always_comb
begin

    //--------------------------------------------
    // Defaults
    //--------------------------------------------

    product_price   = '0;
    quantity        = '0;

    stock_available = 1'b0;
    stock_ok        = 1'b0;
    low_stock       = 1'b0;

    //--------------------------------------------
    // Read Product
    //--------------------------------------------

    if(read_en && id_valid)
    begin

        product_price = price_mem[product_id];
        quantity      = qty_mem[product_id];

        stock_available = (qty_mem[product_id] != 0);

        stock_ok = stock_available;

        low_stock = (qty_mem[product_id] <= 5);

    end

end

endmodule

`timescale 1ns/1ps

module inventory_manager #(
    parameter PRODUCTS    = 32,
    parameter PRICE_WIDTH = 16,
    parameter QTY_WIDTH   = 8
)
(
    input logic clk,
    input logic rst,

    //-------------------------------------------------
    // Product Selection
    //-------------------------------------------------

    input logic [4:0] product_id,

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

//=====================================================
// Memory
//=====================================================

logic [PRICE_WIDTH-1:0] price_mem [0:PRODUCTS-1];
logic [QTY_WIDTH-1:0]   qty_mem   [0:PRODUCTS-1];

integer i;

//=====================================================
// Inventory Update
//=====================================================

always_ff @(posedge clk)
begin

    if(rst)
    begin

        for(i=0;i<PRODUCTS;i=i+1)
        begin
            price_mem[i] <= (i+1)*10;
            qty_mem[i]   <= 20;
        end

    end

    else
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

    if(read_en)
    begin

        product_price = price_mem[product_id];
        quantity      = qty_mem[product_id];

        stock_available = (qty_mem[product_id] != 0);

        stock_ok = stock_available;

        low_stock = (qty_mem[product_id] <= 5);

    end

end

endmodule
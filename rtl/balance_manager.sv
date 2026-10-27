`timescale 1ns/1ps

module balance_manager #(
    parameter BALANCE_WIDTH = 16
)
(
    input  logic                     clk,
    input  logic                     rst,

    //-------------------------------------------------
    // Control Signals
    //-------------------------------------------------
    input  logic                     add_en,
    input  logic                     sub_en,
    input  logic                     refund_en,
    input  logic                     clear_en,

    //-------------------------------------------------
    // Amount Input
    //-------------------------------------------------
    input  logic [BALANCE_WIDTH-1:0] amount_in,

    //-------------------------------------------------
    // Required Amount for Purchase Check
    //-------------------------------------------------
    input  logic [BALANCE_WIDTH-1:0] required_amount,

    //-------------------------------------------------
    // Outputs
    //-------------------------------------------------
    output logic [BALANCE_WIDTH-1:0] current_balance,
    output logic [BALANCE_WIDTH-1:0] refund_amount,

    output logic                     balance_ok,
    output logic                     overflow,
    output logic                     underflow
);

logic [BALANCE_WIDTH:0] temp_sum;

//-----------------------------------------------------
// Balance Management
//-----------------------------------------------------

always_ff @(posedge clk)
begin

    //--------------------------------------------
    // Reset
    //--------------------------------------------

    if (rst)
    begin
        current_balance <= '0;
        refund_amount   <= '0;

        overflow        <= 1'b0;
        underflow       <= 1'b0;
    end

    else
    begin

        //----------------------------------------
        // Default flags every clock
        //----------------------------------------

        overflow  <= 1'b0;
        underflow <= 1'b0;

        //----------------------------------------
        // Highest Priority : Clear
        //----------------------------------------

        if (clear_en)
        begin
            current_balance <= '0;
            refund_amount   <= '0;
        end

        //----------------------------------------
        // Refund
        //----------------------------------------

        else if (refund_en)
        begin
            refund_amount   <= current_balance;
            current_balance <= '0;
        end

        //----------------------------------------
        // Add Money
        //----------------------------------------

        else if (add_en)
        begin

            temp_sum = current_balance + amount_in;

            if (temp_sum[BALANCE_WIDTH])
            begin
                overflow <= 1'b1;
            end
            else
            begin
                current_balance <= temp_sum[BALANCE_WIDTH-1:0];
            end

        end

        //----------------------------------------
        // Purchase
        //----------------------------------------

        else if (sub_en)
        begin

            if (current_balance >= required_amount)
            begin
                current_balance <= current_balance - required_amount;
            end
            else
            begin
                underflow <= 1'b1;
            end

        end

    end

end

//-----------------------------------------------------
// Balance Check Logic
//-----------------------------------------------------

always_comb
begin

    if(current_balance >= required_amount)
        balance_ok = 1'b1;
    else
        balance_ok = 1'b0;

end

endmodule
`timescale 1ns/1ps

module timeout_controller
(
    input logic clk,
    input logic rst,

    input logic transaction_start,
    input logic transaction_done,

    output logic timeout
);

parameter integer TIMEOUT_CYCLES = 20;

logic active;
logic [$clog2(TIMEOUT_CYCLES+1)-1:0] counter;

always_ff @(posedge clk)
begin

    if(rst)
    begin
        active  <= 0;
        counter <= 0;
        timeout <= 0;
    end

    else
    begin

        //--------------------------------------
        // Start transaction
        //--------------------------------------

        if(transaction_start)
        begin
            active  <= 1'b1;
            counter <= 0;
            timeout <= 1'b0;
        end

        //--------------------------------------
        // Transaction completed
        //--------------------------------------

        else if(transaction_done)
        begin
            active  <= 1'b0;
            counter <= 0;
            timeout <= 1'b0;
        end

        //--------------------------------------
        // Counter
        //--------------------------------------

        else if(active)
        begin

            if(counter >= TIMEOUT_CYCLES-1)
            begin
                timeout <= 1'b1;
                active  <= 1'b0;
            end
            else
            begin
                counter <= counter + 1;
            end

        end

    end

end

endmodule
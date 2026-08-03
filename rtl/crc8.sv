`timescale 1ns/1ps

module crc8 #(
    parameter DATA_WIDTH = 32,
    parameter POLYNOMIAL = 8'h07    // x^8 + x^2 + x + 1
)
(
    input  logic [DATA_WIDTH-1:0] data_in,
    output logic [7:0]            crc_out
);

    integer i;

    logic [7:0] crc;

    always_comb
    begin
        crc = 8'h00;

        for(i = DATA_WIDTH-1; i >= 0; i--)
        begin
            if(crc[7] ^ data_in[i])
                crc = (crc << 1) ^ POLYNOMIAL;
            else
                crc = crc << 1;
        end

        crc_out = crc;
    end

endmodule
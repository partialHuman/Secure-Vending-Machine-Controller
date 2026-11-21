`timescale 1ns/1ps

module tb_product_count_invalid_0;
    logic clk = 0;
    logic rst = 0;
    transaction_pkg::payment_request_t request;
    logic request_valid = 0;
    logic request_ready;
    transaction_pkg::response_packet_t response;
    logic response_valid;

    top #(
        .PRODUCT_COUNT(0)
    ) dut (
        .clk(clk),
        .rst(rst),
        .request(request),
        .request_valid(request_valid),
        .request_ready(request_ready),
        .response(response),
        .response_valid(response_valid)
    );
endmodule

module tb_product_count_invalid_33;
    logic clk = 0;
    logic rst = 0;
    transaction_pkg::payment_request_t request;
    logic request_valid = 0;
    logic request_ready;
    transaction_pkg::response_packet_t response;
    logic response_valid;

    top #(
        .PRODUCT_COUNT(33)
    ) dut (
        .clk(clk),
        .rst(rst),
        .request(request),
        .request_valid(request_valid),
        .request_ready(request_ready),
        .response(response),
        .response_valid(response_valid)
    );
endmodule

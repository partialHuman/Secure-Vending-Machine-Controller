`timescale 1ns/1ps

module tb_product_count;

    import transaction_pkg::*;

    //------------------------------------------------------------
    // Test Accounting & Watchdog
    //------------------------------------------------------------
    integer total_tests  = 0;
    integer passed_tests = 0;
    integer failed_tests = 0;
    integer tb_errors    = 0;

    task automatic check_condition(input string desc, input bit cond);
    begin
        total_tests++;
        if (cond) begin
            passed_tests++;
            $display("[PC_TEST PASS] %s", desc);
        end else begin
            failed_tests++;
            tb_errors++;
            $error("[PC_TEST FAIL] %s", desc);
        end
    end
    endtask

    initial begin
        #2000000; // 2 ms global watchdog
        $display("SVM_TB_RESULT: FAIL global watchdog expired");
        $fatal(1, "global watchdog expired");
    end

    //------------------------------------------------------------
    // Clock & Reset Generator
    //------------------------------------------------------------
    logic clk = 0;
    logic rst = 1;
    always #5 clk = ~clk;

    //------------------------------------------------------------
    // Instantiations for configurations 1, 4, 5, 8, 32
    //------------------------------------------------------------
    // Configuration 1
    payment_request_t req_1;
    logic req_valid_1, req_ready_1;
    response_packet_t resp_1;
    logic resp_valid_1;

    top #(.PRODUCT_COUNT(1)) dut_1 (
        .clk(clk), .rst(rst),
        .request(req_1), .request_valid(req_valid_1), .request_ready(req_ready_1),
        .response(resp_1), .response_valid(resp_valid_1)
    );

    // Configuration 4
    payment_request_t req_4;
    logic req_valid_4, req_ready_4;
    response_packet_t resp_4;
    logic resp_valid_4;

    top #(.PRODUCT_COUNT(4)) dut_4 (
        .clk(clk), .rst(rst),
        .request(req_4), .request_valid(req_valid_4), .request_ready(req_ready_4),
        .response(resp_4), .response_valid(resp_valid_4)
    );

    // Configuration 5
    payment_request_t req_5;
    logic req_valid_5, req_ready_5;
    response_packet_t resp_5;
    logic resp_valid_5;

    top #(.PRODUCT_COUNT(5)) dut_5 (
        .clk(clk), .rst(rst),
        .request(req_5), .request_valid(req_valid_5), .request_ready(req_ready_5),
        .response(resp_5), .response_valid(resp_valid_5)
    );

    // Configuration 8
    payment_request_t req_8;
    logic req_valid_8, req_ready_8;
    response_packet_t resp_8;
    logic resp_valid_8;

    top #(.PRODUCT_COUNT(8)) dut_8 (
        .clk(clk), .rst(rst),
        .request(req_8), .request_valid(req_valid_8), .request_ready(req_ready_8),
        .response(resp_8), .response_valid(resp_valid_8)
    );

    // Configuration 32
    payment_request_t req_32;
    logic req_valid_32, req_ready_32;
    response_packet_t resp_32;
    logic resp_valid_32;

    top #(.PRODUCT_COUNT(32)) dut_32 (
        .clk(clk), .rst(rst),
        .request(req_32), .request_valid(req_valid_32), .request_ready(req_ready_32),
        .response(resp_32), .response_valid(resp_valid_32)
    );

    parameter int WATCHDOG_CYCLES = 100;

    //------------------------------------------------------------
    // Generic transaction helper tasks for each configuration
    //------------------------------------------------------------
    task automatic run_txn_1(
        input string desc,
        input payment_t ptype,
        input logic [BALANCE_WIDTH-1:0] amt,
        input logic [PRODUCT_ID_WIDTH-1:0] pid,
        input status_t exp_status,
        input error_t exp_err,
        input bit exp_dispense
    );
        integer wait_cnt;
        bit accepted, got_resp;
        response_packet_t captured_resp;
    begin
        @(negedge clk);
        req_1.payment_type = ptype;
        req_1.amount       = amt;
        req_1.product_id   = pid;
        req_valid_1        = 1'b1;

        wait_cnt = 0; accepted = 0;
        while (!accepted && wait_cnt < WATCHDOG_CYCLES) begin
            if (req_ready_1) begin
                @(posedge clk);
                accepted = 1'b1;
            end else begin
                @(negedge clk);
                wait_cnt++;
            end
        end
        @(negedge clk);
        req_valid_1 = 1'b0;
        check_condition($sformatf("%s: handshake accepted", desc), accepted);

        wait_cnt = 0; got_resp = 0;
        while (!got_resp && wait_cnt < WATCHDOG_CYCLES) begin
            @(posedge clk);
            wait_cnt++;
            if (resp_valid_1) begin
                got_resp = 1'b1;
                captured_resp = resp_1;
            end
        end
        check_condition($sformatf("%s: response received", desc), got_resp);
        check_condition($sformatf("%s: status matches", desc), captured_resp.status == exp_status);
        check_condition($sformatf("%s: error matches", desc), captured_resp.error == exp_err);
        check_condition($sformatf("%s: dispense matches", desc), captured_resp.dispense == exp_dispense);
        #20;
    end
    endtask

    task automatic run_txn_4(
        input string desc,
        input payment_t ptype,
        input logic [BALANCE_WIDTH-1:0] amt,
        input logic [PRODUCT_ID_WIDTH-1:0] pid,
        input status_t exp_status,
        input error_t exp_err,
        input bit exp_dispense
    );
        integer wait_cnt;
        bit accepted, got_resp;
        response_packet_t captured_resp;
    begin
        @(negedge clk);
        req_4.payment_type = ptype;
        req_4.amount       = amt;
        req_4.product_id   = pid;
        req_valid_4        = 1'b1;

        wait_cnt = 0; accepted = 0;
        while (!accepted && wait_cnt < WATCHDOG_CYCLES) begin
            if (req_ready_4) begin
                @(posedge clk);
                accepted = 1'b1;
            end else begin
                @(negedge clk);
                wait_cnt++;
            end
        end
        @(negedge clk);
        req_valid_4 = 1'b0;
        check_condition($sformatf("%s: handshake accepted", desc), accepted);

        wait_cnt = 0; got_resp = 0;
        while (!got_resp && wait_cnt < WATCHDOG_CYCLES) begin
            @(posedge clk);
            wait_cnt++;
            if (resp_valid_4) begin
                got_resp = 1'b1;
                captured_resp = resp_4;
            end
        end
        check_condition($sformatf("%s: response received", desc), got_resp);
        check_condition($sformatf("%s: status matches", desc), captured_resp.status == exp_status);
        check_condition($sformatf("%s: error matches", desc), captured_resp.error == exp_err);
        check_condition($sformatf("%s: dispense matches", desc), captured_resp.dispense == exp_dispense);
        #20;
    end
    endtask

    task automatic run_txn_5(
        input string desc,
        input payment_t ptype,
        input logic [BALANCE_WIDTH-1:0] amt,
        input logic [PRODUCT_ID_WIDTH-1:0] pid,
        input status_t exp_status,
        input error_t exp_err,
        input bit exp_dispense
    );
        integer wait_cnt;
        bit accepted, got_resp;
        response_packet_t captured_resp;
    begin
        @(negedge clk);
        req_5.payment_type = ptype;
        req_5.amount       = amt;
        req_5.product_id   = pid;
        req_valid_5        = 1'b1;

        wait_cnt = 0; accepted = 0;
        while (!accepted && wait_cnt < WATCHDOG_CYCLES) begin
            if (req_ready_5) begin
                @(posedge clk);
                accepted = 1'b1;
            end else begin
                @(negedge clk);
                wait_cnt++;
            end
        end
        @(negedge clk);
        req_valid_5 = 1'b0;
        check_condition($sformatf("%s: handshake accepted", desc), accepted);

        wait_cnt = 0; got_resp = 0;
        while (!got_resp && wait_cnt < WATCHDOG_CYCLES) begin
            @(posedge clk);
            wait_cnt++;
            if (resp_valid_5) begin
                got_resp = 1'b1;
                captured_resp = resp_5;
            end
        end
        check_condition($sformatf("%s: response received", desc), got_resp);
        check_condition($sformatf("%s: status matches", desc), captured_resp.status == exp_status);
        check_condition($sformatf("%s: error matches", desc), captured_resp.error == exp_err);
        check_condition($sformatf("%s: dispense matches", desc), captured_resp.dispense == exp_dispense);
        #20;
    end
    endtask

    task automatic run_txn_8(
        input string desc,
        input payment_t ptype,
        input logic [BALANCE_WIDTH-1:0] amt,
        input logic [PRODUCT_ID_WIDTH-1:0] pid,
        input status_t exp_status,
        input error_t exp_err,
        input bit exp_dispense
    );
        integer wait_cnt;
        bit accepted, got_resp;
        response_packet_t captured_resp;
    begin
        @(negedge clk);
        req_8.payment_type = ptype;
        req_8.amount       = amt;
        req_8.product_id   = pid;
        req_valid_8        = 1'b1;

        wait_cnt = 0; accepted = 0;
        while (!accepted && wait_cnt < WATCHDOG_CYCLES) begin
            if (req_ready_8) begin
                @(posedge clk);
                accepted = 1'b1;
            end else begin
                @(negedge clk);
                wait_cnt++;
            end
        end
        @(negedge clk);
        req_valid_8 = 1'b0;
        check_condition($sformatf("%s: handshake accepted", desc), accepted);

        wait_cnt = 0; got_resp = 0;
        while (!got_resp && wait_cnt < WATCHDOG_CYCLES) begin
            @(posedge clk);
            wait_cnt++;
            if (resp_valid_8) begin
                got_resp = 1'b1;
                captured_resp = resp_8;
            end
        end
        check_condition($sformatf("%s: response received", desc), got_resp);
        check_condition($sformatf("%s: status matches", desc), captured_resp.status == exp_status);
        check_condition($sformatf("%s: error matches", desc), captured_resp.error == exp_err);
        check_condition($sformatf("%s: dispense matches", desc), captured_resp.dispense == exp_dispense);
        #20;
    end
    endtask

    task automatic run_txn_32(
        input string desc,
        input payment_t ptype,
        input logic [BALANCE_WIDTH-1:0] amt,
        input logic [PRODUCT_ID_WIDTH-1:0] pid,
        input status_t exp_status,
        input error_t exp_err,
        input bit exp_dispense
    );
        integer wait_cnt;
        bit accepted, got_resp;
        response_packet_t captured_resp;
    begin
        @(negedge clk);
        req_32.payment_type = ptype;
        req_32.amount       = amt;
        req_32.product_id   = pid;
        req_valid_32        = 1'b1;

        wait_cnt = 0; accepted = 0;
        while (!accepted && wait_cnt < WATCHDOG_CYCLES) begin
            if (req_ready_32) begin
                @(posedge clk);
                accepted = 1'b1;
            end else begin
                @(negedge clk);
                wait_cnt++;
            end
        end
        @(negedge clk);
        req_valid_32 = 1'b0;
        check_condition($sformatf("%s: handshake accepted", desc), accepted);

        wait_cnt = 0; got_resp = 0;
        while (!got_resp && wait_cnt < WATCHDOG_CYCLES) begin
            @(posedge clk);
            wait_cnt++;
            if (resp_valid_32) begin
                got_resp = 1'b1;
                captured_resp = resp_32;
            end
        end
        check_condition($sformatf("%s: response received", desc), got_resp);
        check_condition($sformatf("%s: status matches", desc), captured_resp.status == exp_status);
        check_condition($sformatf("%s: error matches", desc), captured_resp.error == exp_err);
        check_condition($sformatf("%s: dispense matches", desc), captured_resp.dispense == exp_dispense);
        #20;
    end
    endtask

    //------------------------------------------------------------
    // Main Test Sequence
    //------------------------------------------------------------
    initial begin
        req_valid_1 = 0; req_1 = '0;
        req_valid_4 = 0; req_4 = '0;
        req_valid_5 = 0; req_5 = '0;
        req_valid_8 = 0; req_8 = '0;
        req_valid_32 = 0; req_32 = '0;

        rst = 1'b1;
        #30;
        @(negedge clk);
        rst = 1'b0;
        @(posedge clk);
        #1;

        $display("================================================================");
        $display("   PRODUCT_COUNT SYSTEM TESTBENCH (CONFIGS: 1, 4, 5, 8, 32)");
        $display("================================================================");

        //------------------------------------------------------------
        // CONFIGURATION 1 (PRODUCT_COUNT = 1)
        //------------------------------------------------------------
        check_condition("CFG_1: parameter propagated to top", dut_1.PRODUCT_COUNT == 1);
        check_condition("CFG_1: parameter propagated to sec", dut_1.u_security_engine.PRODUCT_COUNT == 1);
        check_condition("CFG_1: parameter propagated to inv", dut_1.u_inventory_manager.PRODUCT_COUNT == 1);
        check_condition("CFG_1: inventory qty_mem depth is 1", $size(dut_1.u_inventory_manager.qty_mem) == 1);
        check_condition("CFG_1: inventory price_mem depth is 1", $size(dut_1.u_inventory_manager.price_mem) == 1);

        // Valid first & only ID 0
        run_txn_1("CFG_1: Valid ID 0", COIN, 16'd10, 5'd0, STATUS_SUCCESS, ERR_NONE, 1'b1);
        check_condition("CFG_1: ID 0 qty decremented to 19", dut_1.u_inventory_manager.qty_mem[0] == 8'd19);

        // Invalid boundary ID 1
        run_txn_1("CFG_1: Invalid boundary ID 1", COIN, 16'd20, 5'd1, STATUS_FAILED, ERR_INVALID_PRODUCT, 1'b0);
        check_condition("CFG_1: ID 0 qty unchanged after invalid ID 1", dut_1.u_inventory_manager.qty_mem[0] == 8'd19);

        // Invalid max ID 31
        run_txn_1("CFG_1: Invalid max ID 31", COIN, 16'd10, 5'd31, STATUS_FAILED, ERR_INVALID_PRODUCT, 1'b0);
        check_condition("CFG_1: ID 0 qty unchanged after invalid ID 31", dut_1.u_inventory_manager.qty_mem[0] == 8'd19);

        //------------------------------------------------------------
        // CONFIGURATION 4 (PRODUCT_COUNT = 4)
        //------------------------------------------------------------
        check_condition("CFG_4: parameter propagated to top", dut_4.PRODUCT_COUNT == 4);
        check_condition("CFG_4: parameter propagated to sec", dut_4.u_security_engine.PRODUCT_COUNT == 4);
        check_condition("CFG_4: parameter propagated to inv", dut_4.u_inventory_manager.PRODUCT_COUNT == 4);
        check_condition("CFG_4: inventory qty_mem depth is 4", $size(dut_4.u_inventory_manager.qty_mem) == 4);
        check_condition("CFG_4: inventory price_mem depth is 4", $size(dut_4.u_inventory_manager.price_mem) == 4);

        // Valid first ID 0
        run_txn_4("CFG_4: Valid ID 0", COIN, 16'd10, 5'd0, STATUS_SUCCESS, ERR_NONE, 1'b1);
        check_condition("CFG_4: ID 0 qty decremented to 19", dut_4.u_inventory_manager.qty_mem[0] == 8'd19);

        // Valid last ID 3
        run_txn_4("CFG_4: Valid ID 3", COIN, 16'd40, 5'd3, STATUS_SUCCESS, ERR_NONE, 1'b1);
        check_condition("CFG_4: ID 3 qty decremented to 19", dut_4.u_inventory_manager.qty_mem[3] == 8'd19);

        // Invalid boundary ID 4
        run_txn_4("CFG_4: Invalid boundary ID 4", COIN, 16'd50, 5'd4, STATUS_FAILED, ERR_INVALID_PRODUCT, 1'b0);

        // Invalid max ID 31
        run_txn_4("CFG_4: Invalid max ID 31", COIN, 16'd10, 5'd31, STATUS_FAILED, ERR_INVALID_PRODUCT, 1'b0);

        //------------------------------------------------------------
        // CONFIGURATION 5 (PRODUCT_COUNT = 5, Default)
        //------------------------------------------------------------
        check_condition("CFG_5: parameter propagated to top", dut_5.PRODUCT_COUNT == 5);
        check_condition("CFG_5: parameter propagated to sec", dut_5.u_security_engine.PRODUCT_COUNT == 5);
        check_condition("CFG_5: parameter propagated to inv", dut_5.u_inventory_manager.PRODUCT_COUNT == 5);
        check_condition("CFG_5: inventory qty_mem depth is 5", $size(dut_5.u_inventory_manager.qty_mem) == 5);
        check_condition("CFG_5: inventory price_mem depth is 5", $size(dut_5.u_inventory_manager.price_mem) == 5);

        // Valid first ID 0
        run_txn_5("CFG_5: Valid ID 0", COIN, 16'd10, 5'd0, STATUS_SUCCESS, ERR_NONE, 1'b1);
        check_condition("CFG_5: ID 0 qty decremented to 19", dut_5.u_inventory_manager.qty_mem[0] == 8'd19);

        // Valid last ID 4
        run_txn_5("CFG_5: Valid ID 4", COIN, 16'd50, 5'd4, STATUS_SUCCESS, ERR_NONE, 1'b1);
        check_condition("CFG_5: ID 4 qty decremented to 19", dut_5.u_inventory_manager.qty_mem[4] == 8'd19);

        // Invalid boundary ID 5
        run_txn_5("CFG_5: Invalid boundary ID 5", COIN, 16'd60, 5'd5, STATUS_FAILED, ERR_INVALID_PRODUCT, 1'b0);

        // Invalid max ID 31
        run_txn_5("CFG_5: Invalid max ID 31", COIN, 16'd10, 5'd31, STATUS_FAILED, ERR_INVALID_PRODUCT, 1'b0);

        //------------------------------------------------------------
        // CONFIGURATION 8 (PRODUCT_COUNT = 8)
        //------------------------------------------------------------
        check_condition("CFG_8: parameter propagated to top", dut_8.PRODUCT_COUNT == 8);
        check_condition("CFG_8: parameter propagated to sec", dut_8.u_security_engine.PRODUCT_COUNT == 8);
        check_condition("CFG_8: parameter propagated to inv", dut_8.u_inventory_manager.PRODUCT_COUNT == 8);
        check_condition("CFG_8: inventory qty_mem depth is 8", $size(dut_8.u_inventory_manager.qty_mem) == 8);
        check_condition("CFG_8: inventory price_mem depth is 8", $size(dut_8.u_inventory_manager.price_mem) == 8);

        // Valid first ID 0
        run_txn_8("CFG_8: Valid ID 0", COIN, 16'd10, 5'd0, STATUS_SUCCESS, ERR_NONE, 1'b1);
        check_condition("CFG_8: ID 0 qty decremented to 19", dut_8.u_inventory_manager.qty_mem[0] == 8'd19);

        // Valid ID 5 (confirms products > 4 work when configured!)
        run_txn_8("CFG_8: Valid ID 5 (exceeds default count 5)", COIN, 16'd60, 5'd5, STATUS_SUCCESS, ERR_NONE, 1'b1);
        check_condition("CFG_8: ID 5 qty decremented to 19", dut_8.u_inventory_manager.qty_mem[5] == 8'd19);

        // Valid last ID 7
        run_txn_8("CFG_8: Valid last ID 7", COIN, 16'd80, 5'd7, STATUS_SUCCESS, ERR_NONE, 1'b1);
        check_condition("CFG_8: ID 7 qty decremented to 19", dut_8.u_inventory_manager.qty_mem[7] == 8'd19);

        // Invalid boundary ID 8
        run_txn_8("CFG_8: Invalid boundary ID 8", COIN, 16'd90, 5'd8, STATUS_FAILED, ERR_INVALID_PRODUCT, 1'b0);

        // Invalid max ID 31
        run_txn_8("CFG_8: Invalid max ID 31", COIN, 16'd10, 5'd31, STATUS_FAILED, ERR_INVALID_PRODUCT, 1'b0);

        //------------------------------------------------------------
        // CONFIGURATION 32 (PRODUCT_COUNT = 32, Maximum)
        //------------------------------------------------------------
        check_condition("CFG_32: parameter propagated to top", dut_32.PRODUCT_COUNT == 32);
        check_condition("CFG_32: parameter propagated to sec", dut_32.u_security_engine.PRODUCT_COUNT == 32);
        check_condition("CFG_32: parameter propagated to inv", dut_32.u_inventory_manager.PRODUCT_COUNT == 32);
        check_condition("CFG_32: inventory qty_mem depth is 32", $size(dut_32.u_inventory_manager.qty_mem) == 32);
        check_condition("CFG_32: inventory price_mem depth is 32", $size(dut_32.u_inventory_manager.price_mem) == 32);

        // Valid first ID 0
        run_txn_32("CFG_32: Valid ID 0", COIN, 16'd10, 5'd0, STATUS_SUCCESS, ERR_NONE, 1'b1);
        check_condition("CFG_32: ID 0 qty decremented to 19", dut_32.u_inventory_manager.qty_mem[0] == 8'd19);

        // Valid ID 15 (middle ID)
        run_txn_32("CFG_32: Valid ID 15", CARD, 16'd160, 5'd15, STATUS_SUCCESS, ERR_NONE, 1'b1);
        check_condition("CFG_32: ID 15 qty decremented to 19", dut_32.u_inventory_manager.qty_mem[15] == 8'd19);

        // Valid last ID 31 (highest encodable ID)
        run_txn_32("CFG_32: Valid last ID 31", CARD, 16'd320, 5'd31, STATUS_SUCCESS, ERR_NONE, 1'b1);
        check_condition("CFG_32: ID 31 qty decremented to 19", dut_32.u_inventory_manager.qty_mem[31] == 8'd19);

        //------------------------------------------------------------
        // Testbench Summary & Marker
        //------------------------------------------------------------
        $display("================================================================");
        $display("   PRODUCT_COUNT TESTBENCH SUMMARY");
        $display("================================================================");
        $display("Total Checks : %0d", total_tests);
        $display("Passed Checks: %0d", passed_tests);
        $display("Failed Checks: %0d", failed_tests);
        $display("TB Errors    : %0d", tb_errors);
        $display("================================================================");

        if (failed_tests != 0 || tb_errors != 0) begin
            $display("SVM_TB_RESULT: FAIL total=%0d passed=%0d failed=%0d tb_errors=%0d",
                     total_tests, passed_tests, failed_tests, tb_errors);
            $fatal(1, "tb_product_count reported failures");
        end else begin
            $display("SVM_TB_RESULT: PASS total=%0d passed=%0d failed=%0d tb_errors=%0d",
                     total_tests, passed_tests, failed_tests, tb_errors);
            $finish;
        end
    end

endmodule

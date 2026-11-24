`timescale 1ns/1ps

module tb_unit_balance;

    import transaction_pkg::*;

    //------------------------------------------------------------
    // Test Accounting & Tracking
    //------------------------------------------------------------
    integer total_tests  = 0;
    integer passed_tests = 0;
    integer failed_tests = 0;
    integer tb_errors    = 0;
    integer kl_hits      = 0;

    task automatic check_condition(input string desc, input bit cond);
    begin
        total_tests++;
        if (cond) begin
            passed_tests++;
            $display("[BAL_TEST PASS] %s", desc);
        end else begin
            failed_tests++;
            tb_errors++;
            $error("[BAL_TEST FAIL] %s", desc);
        end
    end
    endtask

    task automatic kl_note(input string id, input string msg, input bit present);
    begin
        if (present) begin
            kl_hits++;
            $display("SVM_KNOWN_LIMITATION: %s %s", id, msg);
            if ($test$plusargs("STRICT_KL")) begin
                total_tests++;
                failed_tests++;
                tb_errors++;
                $error("STRICT_KL: %s %s", id, msg);
            end
        end
    end
    endtask

    initial begin
        #1000000; // 1 ms global watchdog
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
    // Direct Unit Instance: balance_manager
    //------------------------------------------------------------
    logic add_en;
    logic sub_en;
    logic refund_en;
    logic clear_en;
    logic [BALANCE_WIDTH-1:0] amount_in;
    logic [BALANCE_WIDTH-1:0] required_amount;
    logic [BALANCE_WIDTH-1:0] current_balance;
    logic [BALANCE_WIDTH-1:0] refund_amount;
    logic balance_ok;
    logic overflow;
    logic underflow;

    balance_manager #(
        .BALANCE_WIDTH(BALANCE_WIDTH)
    ) dut_bm (
        .clk(clk),
        .rst(rst),
        .add_en(add_en),
        .sub_en(sub_en),
        .refund_en(refund_en),
        .clear_en(clear_en),
        .amount_in(amount_in),
        .required_amount(required_amount),
        .current_balance(current_balance),
        .refund_amount(refund_amount),
        .balance_ok(balance_ok),
        .overflow(overflow),
        .underflow(underflow)
    );

    //------------------------------------------------------------
    // Integrated Instance: top (for overpayment change propagation)
    //------------------------------------------------------------
    logic request_valid;
    payment_request_t request;
    logic request_ready;
    response_packet_t response;
    logic response_valid;

    top #(
        .PRODUCT_COUNT(5)
    ) dut_top (
        .clk(clk),
        .rst(rst),
        .request_valid(request_valid),
        .request(request),
        .request_ready(request_ready),
        .response(response),
        .response_valid(response_valid),
        .debug_packet(),
        .debug_balance(),
        .debug_refund(),
        .debug_price(),
        .debug_quantity(),
        .debug_security_ok(),
        .debug_busy(),
        .debug_dispense(),
        .debug_complete()
    );

    // Helper task to send request through top
    task automatic send_top_req(input payment_t ptype, input logic [15:0] amt, input logic [4:0] pid);
    begin
        @(negedge clk);
        while (!request_ready) @(negedge clk);
        request.payment_type <= ptype;
        request.amount       <= amt;
        request.product_id   <= pid;
        request_valid        <= 1'b1;
        @(posedge clk);
        @(negedge clk);
        request_valid        <= 1'b0;
    end
    endtask

    // Helper task to wait for response from top
    task automatic wait_top_resp(output response_packet_t r, output bit got_resp);
        integer wait_cycles;
    begin
        got_resp = 0;
        wait_cycles = 0;
        while (!response_valid && wait_cycles < 200) begin
            @(posedge clk);
            wait_cycles++;
        end
        if (response_valid) begin
            got_resp = 1;
            r = response;
            @(posedge clk);
        end
    end
    endtask

    //------------------------------------------------------------
    // Main Test Sequence
    //------------------------------------------------------------
    initial begin
        response_packet_t r;
        bit got_r;
        integer pulse_count;
        integer k;

        add_en          = 1'b0;
        sub_en          = 1'b0;
        refund_en       = 1'b0;
        clear_en        = 1'b0;
        amount_in       = '0;
        required_amount = '0;
        request_valid   = 1'b0;
        request         = '0;

        // Reset
        rst = 1'b1;
        #30;
        @(negedge clk);
        rst = 1'b0;
        @(posedge clk);
        #1;

        $display("================================================================");
        $display("   BALANCE MANAGER DIRECT UNIT & OVERPAYMENT TESTBENCH (M4)");
        $display("================================================================");

        //------------------------------------------------------------
        // SECTION 1: balance_manager Unit Operations
        //------------------------------------------------------------
        $display("\n--- SECTION 1: Unit Operations on balance_manager ---");
        check_condition("BM-UNIT: Reset balance is 0", current_balance == 16'd0);
        check_condition("BM-UNIT: Reset refund_amount is 0", refund_amount == 16'd0);
        check_condition("BM-UNIT: Reset overflow is 0", overflow == 1'b0);
        check_condition("BM-UNIT: Reset underflow is 0", underflow == 1'b0);

        // Addition
        @(negedge clk);
        amount_in = 16'd50;
        add_en    = 1'b1;
        @(posedge clk);
        @(negedge clk);
        add_en    = 1'b0;
        #1;
        check_condition("BM-UNIT: Add 50 results in balance 50", current_balance == 16'd50);

        // Required amount comparison
        required_amount = 16'd30;
        #1;
        check_condition("BM-UNIT: Balance 50 >= 30 asserts balance_ok", balance_ok == 1'b1);

        required_amount = 16'd60;
        #1;
        check_condition("BM-UNIT: Balance 50 < 60 deasserts balance_ok", balance_ok == 1'b0);

        // Overflow detection (16-bit boundary)
        @(negedge clk);
        amount_in = 16'hFFFF;
        add_en    = 1'b1;
        @(posedge clk);
        @(negedge clk);
        add_en    = 1'b0;
        #1;
        check_condition("BM-UNIT: Overflow flag asserted on 16-bit carry", overflow == 1'b1);

        // Full refund
        @(negedge clk);
        refund_en = 1'b1;
        @(posedge clk);
        @(negedge clk);
        refund_en = 1'b0;
        #1;
        check_condition("BM-UNIT: refund_en captures balance to refund_amount", refund_amount == 16'd50);
        check_condition("BM-UNIT: refund_en clears current_balance", current_balance == 16'd0);

        // Clear
        @(negedge clk);
        clear_en = 1'b1;
        @(posedge clk);
        @(negedge clk);
        clear_en = 1'b0;
        #1;
        check_condition("BM-UNIT: clear_en clears refund_amount", refund_amount == 16'd0);

        // Subtraction & Change Capture (KL-001 Direct Unit Verification)
        @(negedge clk);
        amount_in = 16'd50;
        add_en    = 1'b1;
        @(posedge clk);
        @(negedge clk);
        add_en    = 1'b0;
        required_amount = 16'd30;
        @(negedge clk);
        sub_en    = 1'b1;
        @(posedge clk);
        @(negedge clk);
        sub_en    = 1'b0;
        #1;
        check_condition("BM-UNIT: sub_en captures change (50-30=20) to refund_amount", refund_amount == 16'd20);
        check_condition("BM-UNIT: sub_en clears current_balance to 0", current_balance == 16'd0);

        @(negedge clk);
        clear_en = 1'b1;
        @(posedge clk);
        @(negedge clk);
        clear_en = 1'b0;
        #1;
        check_condition("BM-UNIT: clear_en clears refund_amount after purchase", refund_amount == 16'd0);

        //------------------------------------------------------------
        // SECTION 2: Integrated Overpayment & Change Handling (KL-001)
        //------------------------------------------------------------
        $display("\n--- SECTION 2: Integrated Overpayment Verification (top DUT) ---");

        // Requirement 1: Exact payment (Pay 10 for price 10)
        send_top_req(COIN, 16'd10, 5'd0);
        wait_top_resp(r, got_r);
        check_condition("BM-TOP: Exact payment response received", got_r == 1'b1);
        check_condition("BM-TOP: Exact payment status is SUCCESS", r.status == STATUS_SUCCESS);
        check_condition("BM-TOP: Exact payment dispense is 1", r.dispense == 1'b1);
        check_condition("BM-TOP: Exact payment refund is 0", r.refund == 16'd0);

        // Requirement 2: Overpayment (Pay 50 for product 0, price 10) -> change = 40
        send_top_req(NOTE, 16'd50, 5'd0);
        wait_top_resp(r, got_r);
        check_condition("BM-TOP: Overpayment response received", got_r == 1'b1);
        check_condition("BM-TOP: Overpayment status is SUCCESS", r.status == STATUS_SUCCESS);
        check_condition("BM-TOP: Overpayment dispense is 1", r.dispense == 1'b1);
        check_condition("BM-TOP: Overpayment refund is 40", r.refund == 16'd40);
        kl_note("KL-001", "overpayment succeeded but response.refund is 0 (change not returned)",
                (r.status == STATUS_SUCCESS && r.refund == 16'd0));

        // Requirement 3: Minimum Overpayment (Pay 11 for product 0, price 10) -> change = 1
        send_top_req(COIN, 16'd11, 5'd0);
        wait_top_resp(r, got_r);
        check_condition("BM-TOP: Minimum overpay status is SUCCESS", r.status == STATUS_SUCCESS);
        check_condition("BM-TOP: Minimum overpay dispense is 1", r.dispense == 1'b1);
        check_condition("BM-TOP: Minimum overpay refund is 1", r.refund == 16'd1);
        kl_note("KL-001", "minimum overpayment (+1) refund is 0 (change not returned)",
                (r.status == STATUS_SUCCESS && r.refund == 16'd0));

        // Requirement 4: Underpayment (Pay 5 for product 0, price 10) -> full refund = 5
        send_top_req(COIN, 16'd5, 5'd0);
        wait_top_resp(r, got_r);
        check_condition("BM-TOP: Underpayment status is FAILED", r.status == STATUS_FAILED);
        check_condition("BM-TOP: Underpayment error is ERR_BALANCE", r.error == ERR_BALANCE);
        check_condition("BM-TOP: Underpayment dispense is 0", r.dispense == 1'b0);
        check_condition("BM-TOP: Underpayment refunds full tendered amount (5)", r.refund == 16'd5);

        // Requirement 5: Zero payment and invalid transactions remain unchanged
        send_top_req(COIN, 16'd0, 5'd0);
        wait_top_resp(r, got_r);
        check_condition("BM-TOP: Zero amount rejected with STATUS_FAILED", r.status == STATUS_FAILED);
        check_condition("BM-TOP: Zero amount rejected with ERR_INVALID_AMOUNT", r.error == ERR_INVALID_AMOUNT);
        check_condition("BM-TOP: Zero amount dispense is 0", r.dispense == 1'b0);
        check_condition("BM-TOP: Zero amount refund is 0", r.refund == 16'd0);

        send_top_req(payment_t'(3'd6), 16'd10, 5'd0);
        wait_top_resp(r, got_r);
        check_condition("BM-TOP: Invalid payment type rejected with STATUS_FAILED", r.status == STATUS_FAILED);
        check_condition("BM-TOP: Invalid payment type rejected with ERR_INVALID_PAYMENT", r.error == ERR_INVALID_PAYMENT);
        check_condition("BM-TOP: Invalid payment type dispense is 0", r.dispense == 1'b0);
        check_condition("BM-TOP: Invalid payment type refund is 0", r.refund == 16'd0);

        // Requirement 7 & 8: Response stability under backpressure and no duplicate responses
        // Run overpayment (Pay 30 for product 1, price 20) -> change = 10
        send_top_req(RFID, 16'd30, 5'd1);
        wait_top_resp(r, got_r);
        check_condition("BM-TOP: Backpressure test response received", got_r == 1'b1);
        check_condition("BM-TOP: Backpressure test refund is 10", r.refund == 16'd10);
        pulse_count = 0;
        for (k = 0; k < 10; k = k + 1) begin
            if (response_valid) pulse_count++;
            @(posedge clk);
            #1;
            check_condition("BM-TOP: Response refund remains stable while idle", response.refund == 16'd10);
            check_condition("BM-TOP: Response status remains stable while idle", response.status == STATUS_SUCCESS);
        end
        check_condition("BM-TOP: No duplicate responses emitted (pulse count is 0 after capture)", pulse_count == 0);

        // Requirement 9: Repeated transactions do not leak previous transaction change
        // Following the above overpayment (refund 10), send exact payment (Pay 10 for product 0, price 10)
        send_top_req(COIN, 16'd10, 5'd0);
        wait_top_resp(r, got_r);
        check_condition("BM-TOP: Repeated txn exact payment status is SUCCESS", r.status == STATUS_SUCCESS);
        check_condition("BM-TOP: Repeated txn exact payment refund is 0 (no stale leak)", r.refund == 16'd0);

        // Follow with an invalid transaction (Zero Amount)
        send_top_req(COIN, 16'd0, 5'd0);
        wait_top_resp(r, got_r);
        check_condition("BM-TOP: Repeated txn error refund is 0 (no stale leak)", r.refund == 16'd0);

        // Requirement 10: 16-bit boundary case on supported balance/response widths
        // Pay 65535 on WALLET for product 0 (price 10) -> change = 65525
        send_top_req(WALLET, 16'hFFFF, 5'd0);
        wait_top_resp(r, got_r);
        check_condition("BM-TOP: 16-bit max boundary status is SUCCESS", r.status == STATUS_SUCCESS);
        check_condition("BM-TOP: 16-bit max boundary dispense is 1", r.dispense == 1'b1);
        check_condition("BM-TOP: 16-bit max boundary refund is 65525", r.refund == 16'd65525);

        // Final Summary
        $display("\n================================================================");
        $display("   BALANCE TESTBENCH SUMMARY");
        $display("================================================================");
        $display("Total Checks : %0d", total_tests);
        $display("Passed Checks: %0d", passed_tests);
        $display("Failed Checks: %0d", failed_tests);
        $display("KL Hits      : %0d", kl_hits);

        if (failed_tests != 0 || tb_errors != 0) begin
            $display("SVM_TB_RESULT: FAIL total=%0d passed=%0d failed=%0d tb_errors=%0d",
                     total_tests, passed_tests, failed_tests, tb_errors);
            $fatal(1, "tb_unit_balance reported failures");
        end else begin
            $display("SVM_TB_RESULT: PASS total=%0d passed=%0d failed=%0d tb_errors=%0d",
                     total_tests, passed_tests, failed_tests, tb_errors);
            $finish;
        end
    end

endmodule

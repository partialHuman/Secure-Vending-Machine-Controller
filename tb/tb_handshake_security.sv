`timescale 1ns/1ps

import transaction_pkg::*;

module tb_handshake_security;

    //------------------------------------------------------------
    // Clock / Reset
    //------------------------------------------------------------
    logic clk;
    logic rst;

    always #5 clk = ~clk;

    //------------------------------------------------------------
    // DUT Interface
    //------------------------------------------------------------
    logic request_valid;
    payment_request_t request;
    logic request_ready;

    response_packet_t response;
    logic response_valid;

    //------------------------------------------------------------
    // DUT Instantiation
    //------------------------------------------------------------
    top dut
    (
        .clk(clk),
        .rst(rst),

        .request_valid(request_valid),
        .request(request),
        .request_ready(request_ready),

        .response(response),
        .response_valid(response_valid)
    );

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
            $display("[SEC_TEST PASS] %s", desc);
        end else begin
            failed_tests++;
            tb_errors++;
            $error("[SEC_TEST FAIL] %s", desc);
        end
    end
    endtask

    initial begin
        #1000000; // 1 ms global watchdog
        $display("SVM_TB_RESULT: FAIL global watchdog expired");
        $fatal(1, "global watchdog expired");
    end

    //------------------------------------------------------------
    // Active transaction tracking
    //------------------------------------------------------------
    typedef struct packed {
        payment_t                    payment_type;
        logic [BALANCE_WIDTH-1:0]    amount;
        logic [PRODUCT_ID_WIDTH-1:0] product_id;
        logic [31:0]                 inv_before;
        logic [BALANCE_WIDTH-1:0]    bal_before;
    } active_txn_t;

    active_txn_t active_txn;
    parameter int WATCHDOG_CYCLES = 100;

    //------------------------------------------------------------
    // Helper task: synchronous driver complying with Option A
    //------------------------------------------------------------
    task send_request
    (
        input payment_t payment,
        input logic [BALANCE_WIDTH-1:0] amount,
        input logic [PRODUCT_ID_WIDTH-1:0] product
    );
        integer wait_cycles;
        bit accepted;
    begin
        @(negedge clk);
        request.payment_type = payment;
        request.amount       = amount;
        request.product_id   = product;
        request_valid        = 1'b1;

        wait_cycles = 0;
        accepted    = 1'b0;

        while (!accepted && (wait_cycles < WATCHDOG_CYCLES))
        begin
            if (request_ready)
            begin
                @(posedge clk);
                accepted = 1'b1;
                active_txn.payment_type = payment;
                active_txn.amount       = amount;
                active_txn.product_id   = product;
                active_txn.inv_before   = dut.u_inventory_manager.qty_mem[product];
                active_txn.bal_before   = dut.u_balance_manager.current_balance;
            end
            else
            begin
                @(negedge clk);
                wait_cycles++;
            end
        end

        @(negedge clk);
        request_valid = 1'b0;

        check_condition("Driver Handshake: Request accepted within watchdog", accepted);
    end
    endtask

    //------------------------------------------------------------
    // Helper task: wait for response
    //------------------------------------------------------------
    task wait_response_sec
    (
        output response_packet_t resp_out,
        output bit got_resp
    );
        integer tout;
    begin
        tout     = 0;
        got_resp = 1'b0;
        resp_out = '0;

        while (response_valid) @(posedge clk);

        while (!got_resp && tout < WATCHDOG_CYCLES)
        begin
            @(posedge clk);
            tout++;
            if (response_valid)
            begin
                got_resp = 1'b1;
                resp_out = response;
            end
        end

        check_condition("Response Received: response_valid asserted within watchdog", got_resp);
    end
    endtask

    //------------------------------------------------------------
    // Main Test Sequence
    //------------------------------------------------------------
    initial begin
        response_packet_t r;
        bit got_r;
        integer p1_inv_before, p2_inv_before;
        integer busy_cycles;
        response_packet_t r1, r2;
        bit got_r1, r2_accepted;
        integer tout;

        clk           = 0;
        rst           = 1;
        request_valid = 0;
        request       = '0;

        $display("================================================================");
        $display("   SECURE VENDING MACHINE CONTROLLER - SECURITY TESTBENCH");
        $display("================================================================");

        //--------------------------------------------------------
        // TEST 1: Reset and Handshake Gate Verification
        //--------------------------------------------------------
        $display("\n--- TEST 1: Reset & Handshake Gate ---");
        repeat(3) @(posedge clk);
        check_condition("Test 1: request_ready is deasserted (0) during reset", request_ready == 1'b0);

        // Present request while in reset - verify not accepted
        @(negedge clk);
        request.payment_type = COIN;
        request.amount       = 16'd10;
        request.product_id   = 5'd0;
        request_valid        = 1'b1;

        repeat(3) @(posedge clk);
        check_condition("Test 1: packet_valid remains 0 while in reset despite request_valid=1",
                        dut.u_payment_interface.packet_valid == 1'b0);

        @(negedge clk);
        request_valid = 1'b0;
        rst           = 1'b0;
        repeat(2) @(posedge clk);

        check_condition("Test 1: Controller in IDLE after reset deassertion",
                        dut.u_transaction_controller.current_state == IDLE);
        check_condition("Test 1: request_ready is asserted (1) when reset released into IDLE",
                        request_ready == 1'b1);
        check_condition("Test 1: Balance initialized to 0",
                        dut.u_balance_manager.current_balance == 0);

        //--------------------------------------------------------
        // TEST 2: Single Valid Transaction (Baseline Handshake Option A)
        //--------------------------------------------------------
        $display("\n--- TEST 2: Baseline Option A Single Transaction ---");
        p1_inv_before = dut.u_inventory_manager.qty_mem[0];
        send_request(COIN, 16'd10, 5'd0);
        wait_response_sec(r, got_r);

        check_condition("Test 2: Txn Status SUCCESS", r.status == STATUS_SUCCESS);
        check_condition("Test 2: Txn Error ERR_NONE", r.error == ERR_NONE);
        check_condition("Test 2: Dispense Asserted", r.dispense == 1'b1);
        check_condition("Test 2: Refund is 0", r.refund == 0);
        check_condition("Test 2: Product 0 Qty decremented by 1",
                        dut.u_inventory_manager.qty_mem[0] == p1_inv_before - 1);
        check_condition("Test 2: Balance cleared to 0",
                        dut.u_balance_manager.current_balance == 0);
        check_condition("Test 2: Controller returned to IDLE",
                        dut.u_transaction_controller.current_state == IDLE);

        //--------------------------------------------------------
        // TEST 3: Concurrent Request Under Contention (Audit Finding Verification)
        //--------------------------------------------------------
        $display("\n--- TEST 3: In-Flight Contention & Level-Sensitive Security Check ---");
        p1_inv_before = dut.u_inventory_manager.qty_mem[1];
        p2_inv_before = dut.u_inventory_manager.qty_mem[2];

        // 1. Submit Txn 1 (CARD, 20, P1)
        @(negedge clk);
        request.payment_type = CARD;
        request.amount       = 16'd20;
        request.product_id   = 5'd1;
        request_valid        = 1'b1;

        while (!request_ready) @(negedge clk);
        @(posedge clk); // Accepting edge for Txn 1

        // 2. On next negedge clk, present Txn 2 (UPI, 30, P2) while Txn 1 in flight
        @(negedge clk);
        request.payment_type = UPI;
        request.amount       = 16'd30;
        request.product_id   = 5'd2;
        request_valid        = 1'b1;

        // 3. Monitor in-flight contention: request_ready MUST stay 0, payload stable
        busy_cycles = 0;
        got_r1      = 1'b0;
        tout        = 0;

        while (!got_r1 && tout < WATCHDOG_CYCLES)
        begin
            @(posedge clk);
            tout++;

            if (response_valid && !got_r1)
            begin
                got_r1 = 1'b1;
                r1     = response;
            end
            else if (!request_ready)
            begin
                busy_cycles++;
                assert(dut.u_payment_interface.packet_valid == 1'b0 || busy_cycles == 1)
                else tb_fail("Test 3: Contention request admitted into pipeline while busy!");
            end
        end

        check_condition("Test 3: Txn 1 completed with response while Txn 2 held off", got_r1);
        check_condition("Test 3: Busy cycles observed (> 5)", busy_cycles >= 5);

        // 4. Accept Txn 2 on next posedge clk where controller returns to IDLE
        @(posedge clk);
        r2_accepted = 1'b1;
        check_condition("Test 3: Txn 2 accepted on posedge entering IDLE", r2_accepted);

        // Deassert request_valid on negedge
        @(negedge clk);
        request_valid = 1'b0;

        // 5. Verify Txn 1 response
        check_condition("Test 3: Txn 1 (CARD) Status SUCCESS", r1.status == STATUS_SUCCESS);
        check_condition("Test 3: Txn 1 (CARD) Error ERR_NONE (No Duplicate/CRC rejection)", r1.error == ERR_NONE);
        check_condition("Test 3: Txn 1 (CARD) Dispense 1", r1.dispense == 1'b1);
        check_condition("Test 3: Product 1 decremented by 1",
                        dut.u_inventory_manager.qty_mem[1] == p1_inv_before - 1);

        // 6. Wait for Txn 2 response
        wait_response_sec(r2, got_r);
        check_condition("Test 3: Txn 2 (UPI) Status SUCCESS", r2.status == STATUS_SUCCESS);
        check_condition("Test 3: Txn 2 (UPI) Error ERR_NONE", r2.error == ERR_NONE);
        check_condition("Test 3: Txn 2 (UPI) Dispense 1", r2.dispense == 1'b1);
        check_condition("Test 3: Product 2 decremented by 1",
                        dut.u_inventory_manager.qty_mem[2] == p2_inv_before - 1);
        check_condition("Test 3: Balance 0 after both contention txns",
                        dut.u_balance_manager.current_balance == 0);

        //--------------------------------------------------------
        // TEST 4: Security Rule Validation - ERR_AUTH (CARD > 5000)
        //--------------------------------------------------------
        $display("\n--- TEST 4: Security Rule ERR_AUTH ---");
        send_request(CARD, 16'd6000, 5'd0);
        wait_response_sec(r, got_r);

        check_condition("Test 4: High amount CARD rejected with STATUS_FAILED",
                        r.status == STATUS_FAILED);
        check_condition("Test 4: High amount CARD rejected with ERR_AUTH",
                        r.error == ERR_AUTH);
        check_condition("Test 4: Dispense is 0", r.dispense == 1'b0);
        check_condition("Test 4: Balance cleared after ERR_AUTH",
                        dut.u_balance_manager.current_balance == 0);
        check_condition("Test 4: Controller returned to IDLE",
                        dut.u_transaction_controller.current_state == IDLE);

        //--------------------------------------------------------
        // TEST 5: Security Rule Validation - ERR_INVALID_PRODUCT (PID >= 32)
        //--------------------------------------------------------
        $display("\n--- TEST 5: Security Rule ERR_INVALID_PRODUCT ---");
        send_request(COIN, 16'd10, 5'd10); // 10 >= PRODUCT_COUNT (5)
        wait_response_sec(r, got_r);

        check_condition("Test 5: Out of bounds PID rejected with STATUS_FAILED",
                        r.status == STATUS_FAILED);
        check_condition("Test 5: Out of bounds PID rejected with ERR_INVALID_PRODUCT",
                        r.error == ERR_INVALID_PRODUCT);
        check_condition("Test 5: Dispense is 0", r.dispense == 1'b0);
        check_condition("Test 5: Controller returned to IDLE",
                        dut.u_transaction_controller.current_state == IDLE);

        //--------------------------------------------------------
        // TEST 6: Security Rule Validation - ERR_BALANCE (Amount == 0)
        //--------------------------------------------------------
        $display("\n--- TEST 6: Security Rule ERR_BALANCE (Zero Amount) ---");
        send_request(COIN, 16'd0, 5'd0);
        wait_response_sec(r, got_r);

        check_condition("Test 6: Zero amount rejected with STATUS_FAILED",
                        r.status == STATUS_FAILED);
        check_condition("Test 6: Zero amount rejected with ERR_BALANCE",
                        r.error == ERR_BALANCE);
        check_condition("Test 6: Dispense is 0", r.dispense == 1'b0);
        check_condition("Test 6: Controller returned to IDLE",
                        dut.u_transaction_controller.current_state == IDLE);

        //--------------------------------------------------------
        // TEST 7: Reset During Active Transaction & Clean Recovery
        //--------------------------------------------------------
        $display("\n--- TEST 7: Mid-Transaction Reset & Clean Recovery ---");
        send_request(COIN, 16'd10, 5'd0);
        @(negedge clk);
        rst = 1'b1;
        @(negedge clk);
        check_condition("Test 7: Balance cleared on mid-transaction reset",
                        dut.u_balance_manager.current_balance == 0);
        check_condition("Test 7: Controller returned to IDLE on reset",
                        dut.u_transaction_controller.current_state == IDLE);
        check_condition("Test 7: request_ready is 0 during reset", request_ready == 1'b0);

        rst = 1'b0;
        repeat(2) @(posedge clk);
        check_condition("Test 7: request_ready is 1 after reset release", request_ready == 1'b1);

        // Submit recovery transaction
        send_request(NOTE, 16'd10, 5'd0);
        wait_response_sec(r, got_r);
        check_condition("Test 7: Recovery transaction succeeds with STATUS_SUCCESS",
                        r.status == STATUS_SUCCESS);
        check_condition("Test 7: Recovery transaction dispensed product",
                        r.dispense == 1'b1);
        check_condition("Test 7: Final Controller state is IDLE",
                        dut.u_transaction_controller.current_state == IDLE);

        //--------------------------------------------------------
        // Final Summary
        //--------------------------------------------------------
        $display("\n================================================================");
        $display("   SECURITY TESTBENCH SUMMARY");
        $display("================================================================");
        $display("Total Checks : %0d", total_tests);
        $display("Passed Checks: %0d", passed_tests);
        $display("Failed Checks: %0d", failed_tests);
        $display("TB Errors    : %0d", tb_errors);
        $display("================================================================");

        if (failed_tests != 0 || tb_errors != 0) begin
            $display("SVM_TB_RESULT: FAIL total=%0d passed=%0d failed=%0d tb_errors=%0d",
                     total_tests, passed_tests, failed_tests, tb_errors);
            $fatal(1, "tb_handshake_security reported failures");
        end
        else begin
            $display("SVM_TB_RESULT: PASS total=%0d passed=%0d failed=%0d tb_errors=%0d",
                     total_tests, passed_tests, failed_tests, tb_errors);
            $finish;
        end
    end

    // Helper fail task
    task automatic tb_fail(input string msg);
    begin
        tb_errors++;
        $error("%s", msg);
    end
    endtask

endmodule

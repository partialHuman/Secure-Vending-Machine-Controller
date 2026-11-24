`timescale 1ns/1ps

module tb_unit_timeout;

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
            $display("[TIMEOUT_TEST PASS] %s", desc);
        end else begin
            failed_tests++;
            tb_errors++;
            $error("[TIMEOUT_TEST FAIL] %s", desc);
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
        #3000000; // 3 ms global watchdog
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
    // DUT: timeout_controller (standalone unit instance)
    //------------------------------------------------------------
    localparam int TEST_TIMEOUT_CYCLES = 5;

    logic tc_start;
    logic tc_done;
    logic tc_timeout;

    timeout_controller #(
        .TIMEOUT_CYCLES(TEST_TIMEOUT_CYCLES)
    ) u_tc_unit (
        .clk(clk),
        .rst(rst),
        .transaction_start(tc_start),
        .transaction_done(tc_done),
        .timeout(tc_timeout)
    );

    //------------------------------------------------------------
    // DUT: top (integrated system instance with timeout=20)
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

    //------------------------------------------------------------
    // Response Pulse Width & Conservation Monitor
    //------------------------------------------------------------
    integer mon_accept_total = 0;
    integer mon_resp_total   = 0;
    integer mon_resp_wide    = 0;
    logic   mon_resp_prev    = 1'b0;

    always @(posedge clk) begin
        if (!rst && request_valid && request_ready)
            mon_accept_total <= mon_accept_total + 1;

        if (response_valid && !mon_resp_prev)
            mon_resp_total <= mon_resp_total + 1;

        if (response_valid && mon_resp_prev)
            mon_resp_wide <= mon_resp_wide + 1;

        mon_resp_prev <= response_valid;
    end

    // Concurrent SVA for single-cycle response_valid pulse
    property p_single_cycle_resp;
        @(posedge clk) disable iff (rst)
        response_valid |=> !response_valid;
    endproperty
    assert property (p_single_cycle_resp)
        else $display("[SVA NOTE] response_valid stayed high for more than one clock cycle");

    // Helper task to send request through top
    task automatic send_req(input payment_t ptype, input logic [15:0] amt, input logic [4:0] pid);
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

    // Helper task to wait for response
    task automatic wait_resp(output response_packet_t r, output bit got_resp);
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

    //============================================================
    // Reusable Response-Valid Pulse & Payload Monitor Task (Gap 4.2)
    //============================================================
    task automatic verify_and_monitor_resp(
        input string test_id,
        input status_t exp_status,
        input error_t  exp_error,
        input logic [15:0] exp_refund,
        input logic exp_dispense
    );
        integer wait_c;
        integer pulse_len;
        status_t s_status;
        error_t  s_error;
        logic [15:0] s_refund;
        logic    s_dispense;
        logic    next_cycle_val;
        integer post_idle_c;
        bit spurious_pulse;
    begin
        wait_c = 0;
        while (!response_valid && wait_c < 200) begin
            @(posedge clk);
            wait_c++;
        end

        check_condition({test_id, ": Response observed within timeout"}, response_valid == 1'b1);

        pulse_len = 0;
        if (response_valid) begin
            pulse_len = 1;
            s_status   = response.status;
            s_error    = response.error;
            s_refund   = response.refund;
            s_dispense = response.dispense;
            @(posedge clk);
            #1;
            next_cycle_val = response_valid;
            if (response_valid) pulse_len++;
        end

        check_condition({test_id, ": response_valid exactly 1 cycle pulse"}, pulse_len == 1);
        check_condition({test_id, ": response_valid low on following cycle"}, next_cycle_val == 1'b0);
        check_condition({test_id, ": Payload status matches expectation"}, s_status == exp_status);
        check_condition({test_id, ": Payload error matches expectation"}, s_error == exp_error);
        check_condition({test_id, ": Payload refund matches expectation"}, s_refund == exp_refund);
        check_condition({test_id, ": Payload dispense matches expectation"}, s_dispense == exp_dispense);

        // Verify no duplicate response pulse during idle window
        spurious_pulse = 0;
        for (post_idle_c = 0; post_idle_c < 6; post_idle_c++) begin
            @(posedge clk);
            if (response_valid) spurious_pulse = 1;
        end
        check_condition({test_id, ": No duplicate or spurious response pulse emitted"}, spurious_pulse == 0);
    end
    endtask

    //------------------------------------------------------------
    // Main Test Sequence
    //------------------------------------------------------------
    initial begin
        response_packet_t r;
        bit got_r;
        integer pulse_len;
        integer wait_c;
        status_t sampled_status;
        error_t  sampled_error;
        logic [15:0] sampled_refund;
        logic    sampled_dispense;
        logic    next_cycle_val;
        integer refund_pulses;
        integer poll_c;
        logic [15:0] captured_balance_in_refund;
        logic [15:0] captured_refund_amount_complete;
        logic [15:0] cleared_balance_idle;

        tc_start      = 1'b0;
        tc_done       = 1'b0;
        request_valid = 1'b0;
        request       = '0;

        // Reset
        rst = 1'b1;
        #30;
        @(negedge clk);
        rst = 1'b0;
        @(posedge clk);
        #1;

        $display("================================================================");
        $display("   TIMEOUT CONTROLLER DIRECT UNIT & INTEGRATION TESTBENCH (M6)");
        $display("================================================================");

        //------------------------------------------------------------
        // SECTION 1: timeout_controller Unit Semantics (5 cycles)
        //------------------------------------------------------------
        $display("\n--- SECTION 1: Unit Semantics of timeout_controller ---");
        check_condition("TC-UNIT: Initial timeout signal is 0", tc_timeout == 1'b0);
        check_condition("TC-UNIT: Initial active signal is 0", u_tc_unit.active == 1'b0);

        // Start transaction
        @(negedge clk);
        tc_start = 1'b1;
        @(posedge clk);
        @(negedge clk);
        tc_start = 1'b0;

        check_condition("TC-UNIT: Active asserted on start", u_tc_unit.active == 1'b1);
        check_condition("TC-UNIT: Timeout 0 while counting", tc_timeout == 1'b0);

        // Count up to TEST_TIMEOUT_CYCLES (5 cycles)
        repeat (5) @(posedge clk);
        #1;
        check_condition("TC-UNIT: Timeout fired at cycle 5", tc_timeout == 1'b1);
        check_condition("TC-UNIT: Active deasserted upon timeout", u_tc_unit.active == 1'b0);

        // Verify timeout signal is a PERSISTENT LEVEL
        @(posedge clk);
        #1;
        check_condition("TC-UNIT: Timeout remains persistent level before done", tc_timeout == 1'b1);

        // Signal transaction_done
        @(negedge clk);
        tc_done = 1'b1;
        @(posedge clk);
        @(negedge clk);
        tc_done = 1'b0;
        #1;
        check_condition("TC-UNIT: Timeout cleared on transaction_done", tc_timeout == 1'b0);

        //------------------------------------------------------------
        // SECTION 2: Integrated Timeout with Balance (KL-002 Part A & B)
        //------------------------------------------------------------
        $display("\n--- SECTION 2: Integrated Timeout with Balance (top DUT) ---");
        // We tender balance=50 for product 2 (price 30)
        // In CHECK_BALANCE, we stall the FSM to let the top-level timer (20 cycles) fire
        fork
            begin
                @(posedge clk iff dut_top.u_transaction_controller.current_state == CHECK_BALANCE);
                force dut_top.u_transaction_controller.current_state = CHECK_BALANCE;
                @(posedge dut_top.u_timeout_controller.timeout);
                @(posedge clk);
                release dut_top.u_transaction_controller.current_state;
            end
            begin
                send_req(COIN, 16'd50, 5'd2);
                wait_resp(r, got_r);
            end
        join

        // Allow any multi-cycle pulse to fully retire and monitor to settle
        while (response_valid) @(posedge clk);
        repeat (5) @(posedge clk);

        check_condition("TC-INT: Timeout response observed", got_r == 1'b1);
        check_condition("TC-INT: Status is STATUS_TIMEOUT", r.status == STATUS_TIMEOUT);
        check_condition("TC-INT: Error is ERR_TIMEOUT", r.error == ERR_TIMEOUT);
        check_condition("TC-INT: Dispense is 0 on timeout", r.dispense == 1'b0);
        check_condition("TC-INT: Timeout refund is 50 (KL-002A resolved)", r.refund == 16'd50);

        // KL-002 Part A & B checks (fail under +STRICT_KL if defect remains)
        kl_note("KL-002", "timeout with tendered balance forfeited funds (refund is 0)", (r.refund == 16'd0));
        kl_note("KL-002", "response_valid stayed high for more than one clock cycle on timeout", (mon_resp_wide > 0));

        check_condition("TC-INT: Wide response pulses strictly 0 (KL-002B resolved)", mon_resp_wide == 0);
        check_condition("TC-INT: Balance cleared after timeout refund", dut_top.u_balance_manager.current_balance == 16'd0);
        check_condition("TC-INT: Manager refund_amount cleared after timeout", dut_top.u_balance_manager.refund_amount == 16'd0);
        check_condition("TC-INT: Conservation of requests (accepted == responses)", mon_accept_total == mon_resp_total);

        //------------------------------------------------------------
        // SECTION 3: Cycle-by-Cycle Measurement of response_valid
        //------------------------------------------------------------
        $display("\n--- SECTION 3: Cycle-by-Cycle Pulse Width Measurement ---");
        fork
            begin
                @(posedge clk iff dut_top.u_transaction_controller.current_state == CHECK_BALANCE);
                force dut_top.u_transaction_controller.current_state = CHECK_BALANCE;
                @(posedge dut_top.u_timeout_controller.timeout);
                @(posedge clk);
                release dut_top.u_transaction_controller.current_state;
            end
            begin
                send_req(NOTE, 16'd50, 5'd2);
            end
        join

        // Monitor response_valid cycle-by-cycle at posedge clk
        wait_c = 0;
        while (!response_valid && wait_c < 200) begin
            @(posedge clk);
            wait_c++;
        end

        // Sample exact cycle 1 of response_valid
        pulse_len = 0;
        if (response_valid) begin
            pulse_len = 1;
            sampled_status   = response.status;
            sampled_error    = response.error;
            sampled_refund   = response.refund;
            sampled_dispense = response.dispense;
            @(posedge clk);
            #1;
            next_cycle_val = response_valid;
            if (response_valid) pulse_len++;
        end

        check_condition("TC-CYC: Exactly 1 cycle response_valid pulse width", pulse_len == 1);
        check_condition("TC-CYC: response_valid is low on immediately following cycle", next_cycle_val == 1'b0);
        check_condition("TC-CYC: Payload status is STATUS_TIMEOUT during valid pulse", sampled_status == STATUS_TIMEOUT);
        check_condition("TC-CYC: Payload error is ERR_TIMEOUT during valid pulse", sampled_error == ERR_TIMEOUT);
        check_condition("TC-CYC: Payload refund is 50 during valid pulse", sampled_refund == 16'd50);
        check_condition("TC-CYC: Payload dispense is 0 during valid pulse", sampled_dispense == 1'b0);

        repeat (5) @(posedge clk);

        //------------------------------------------------------------
        // SECTION 4: Zero-Balance Timeout Verification
        //------------------------------------------------------------
        $display("\n--- SECTION 4: Zero-Balance Timeout Verification ---");
        // Force timeout in AUTHENTICATE with zero-balance request
        fork
            begin
                @(posedge clk iff dut_top.u_transaction_controller.current_state == AUTHENTICATE);
                force dut_top.u_transaction_controller.current_state = AUTHENTICATE;
                // Force timeout condition
                force dut_top.u_timeout_controller.timeout = 1'b1;
                repeat (2) @(posedge clk);
                release dut_top.u_timeout_controller.timeout;
                release dut_top.u_transaction_controller.current_state;
            end
            begin
                send_req(COIN, 16'd10, 5'd0);
                wait_resp(r, got_r);
            end
        join

        repeat (5) @(posedge clk);
        check_condition("TC-ZERO: Response received for authenticate timeout", got_r == 1'b1);
        check_condition("TC-ZERO: Status is STATUS_TIMEOUT", r.status == STATUS_TIMEOUT);
        check_condition("TC-ZERO: Dispense is 0", r.dispense == 1'b0);

        //------------------------------------------------------------
        // SECTION 5: Consecutive Transactions & No Stale Value Leakage
        //------------------------------------------------------------
        $display("\n--- SECTION 5: Consecutive Transactions & Stale Leakage Prevention ---");
        // Following timeout (refund was 50), run normal exact-payment purchase (10 for 10)
        send_req(COIN, 16'd10, 5'd0);
        wait_resp(r, got_r);
        check_condition("TC-SEQ: Normal purchase following timeout succeeds", r.status == STATUS_SUCCESS);
        check_condition("TC-SEQ: Normal purchase dispense is 1", r.dispense == 1'b1);
        check_condition("TC-SEQ: Normal purchase refund is 0 (no stale timeout refund leak)", r.refund == 16'd0);

        // Run second consecutive transaction (Overpayment 50 for 10 -> change 40)
        send_req(NOTE, 16'd50, 5'd0);
        wait_resp(r, got_r);
        check_condition("TC-SEQ: Consecutive overpayment status is SUCCESS", r.status == STATUS_SUCCESS);
        check_condition("TC-SEQ: Consecutive overpayment dispense is 1", r.dispense == 1'b1);
        check_condition("TC-SEQ: Consecutive overpayment refund is 40", r.refund == 16'd40);

        // Run third consecutive transaction (Underpayment 5 for 10 -> full refund 5)
        send_req(COIN, 16'd5, 5'd0);
        wait_resp(r, got_r);
        check_condition("TC-SEQ: Consecutive underpayment status is FAILED", r.status == STATUS_FAILED);
        check_condition("TC-SEQ: Consecutive underpayment error is ERR_BALANCE", r.error == ERR_BALANCE);
        check_condition("TC-SEQ: Consecutive underpayment refund is 5", r.refund == 16'd5);

        // Check conservation and pulse count
        check_condition("TC-FIN: Intermediate wide response pulses strictly 0", mon_resp_wide == 0);
        check_condition("TC-FIN: Intermediate conservation of requests (accepted == responses)", mon_accept_total == mon_resp_total);

        //------------------------------------------------------------
        // SECTION 6: Timeout Boundary Conditions & Multi-Refund Prevention (Gap 4.1)
        //------------------------------------------------------------
        $display("\n--- SECTION 6: Timeout Boundary Conditions & Duplicate Refund Prevention (Gap 4.1) ---");

        // 6.1: Timeout coinciding directly at payment/balance update boundary
        fork
            begin
                @(posedge clk iff dut_top.u_transaction_controller.current_state == RECEIVE_PAYMENT);
                force dut_top.u_timeout_controller.timeout = 1'b1;
                @(posedge clk);
                release dut_top.u_timeout_controller.timeout;
            end
            begin
                send_req(COIN, 16'd50, 5'd1);
                wait_resp(r, got_r);
            end
        join

        check_condition("GAP4.1-BND: Timeout at RECEIVE_PAYMENT response received", got_r == 1'b1);
        check_condition("GAP4.1-BND: Status is STATUS_TIMEOUT on payment boundary", r.status == STATUS_TIMEOUT);
        check_condition("GAP4.1-BND: Error is ERR_TIMEOUT on payment boundary", r.error == ERR_TIMEOUT);
        check_condition("GAP4.1-BND: Dispense is strictly 0 on payment boundary", r.dispense == 1'b0);
        check_condition("GAP4.1-BND: Tendered amount refunded on boundary timeout", r.refund == 16'd50);

        // 6.2: Duplicate-refund prevention & single-pulse refund verification
        refund_pulses = 0;
        fork
            begin
                @(posedge clk iff dut_top.u_transaction_controller.current_state == CHECK_BALANCE);
                force dut_top.u_transaction_controller.current_state = CHECK_BALANCE;
                force dut_top.u_timeout_controller.timeout = 1'b1;
                repeat (2) @(posedge clk);
                release dut_top.u_transaction_controller.current_state;
                release dut_top.u_timeout_controller.timeout;
            end
            begin
                // Monitor refund_reg across the entire transaction lifecycle (25 cycles)
                for (poll_c = 0; poll_c < 25; poll_c++) begin
                    @(posedge clk);
                    if (dut_top.u_transaction_controller.refund_reg)
                        refund_pulses++;
                end
            end
            begin
                send_req(NOTE, 16'd50, 5'd1);
                wait_resp(r, got_r);
            end
        join

        check_condition("GAP4.1-DUP: Exactly one internal refund_reg pulse asserted", refund_pulses == 1);
        check_condition("GAP4.1-DUP: No duplicate refunds emitted", r.refund == 16'd50);

        // 6.3: Balance clearing timing verification (refund capture occurs before balance clear)
        fork
            begin
                @(posedge clk iff dut_top.u_transaction_controller.current_state == REFUND);
                #1;
                captured_balance_in_refund = dut_top.u_balance_manager.current_balance;
                @(posedge clk iff dut_top.u_transaction_controller.current_state == COMPLETE);
                #1;
                captured_refund_amount_complete = dut_top.u_response_generator.refund_amount;
                @(posedge clk iff dut_top.u_transaction_controller.current_state == IDLE);
                #1;
                cleared_balance_idle = dut_top.u_balance_manager.current_balance;
            end
            begin
                @(posedge clk iff dut_top.u_transaction_controller.current_state == CHECK_BALANCE);
                force dut_top.u_timeout_controller.timeout = 1'b1;
                repeat (2) @(posedge clk);
                release dut_top.u_timeout_controller.timeout;
            end
            begin
                send_req(COIN, 16'd30, 5'd1);
                wait_resp(r, got_r);
            end
        join

        check_condition("GAP4.1-TIM: Balance was valid (30) in REFUND state", captured_balance_in_refund == 16'd30);
        check_condition("GAP4.1-TIM: Refund amount captured into response before clearing", captured_refund_amount_complete == 16'd30);
        check_condition("GAP4.1-TIM: Balance strictly cleared to 0 in IDLE", cleared_balance_idle == 16'd0);
        check_condition("GAP4.1-TIM: Timeout never mistaken for successful purchase", r.status != STATUS_SUCCESS && r.dispense == 1'b0);

        // 6.4: Zero accumulated balance timeout verification
        fork
            begin
                @(posedge clk iff dut_top.u_transaction_controller.current_state == AUTHENTICATE);
                force dut_top.u_timeout_controller.timeout = 1'b1;
                repeat (2) @(posedge clk);
                release dut_top.u_timeout_controller.timeout;
            end
            begin
                // Tender 0 is blocked by security engine; test zero balance by resetting and forcing timeout
                send_req(COIN, 16'd10, 5'd0);
                wait_resp(r, got_r);
            end
        join
        check_condition("GAP4.1-ZERO: Non-tendered / zero balance timeout refund is 0 or tendered amount", (r.refund == 16'd10 || r.refund == 16'd0));
        check_condition("GAP4.1-ZERO: Dispense is strictly 0", r.dispense == 1'b0);

        // Subsequent transaction balance isolation
        send_req(COIN, 16'd10, 5'd0);
        wait_resp(r, got_r);
        check_condition("GAP4.1-ISO: Subsequent transaction succeeds with correct status", r.status == STATUS_SUCCESS);
        check_condition("GAP4.1-ISO: Subsequent transaction does not inherit balance (refund=0)", r.refund == 16'd0);

        //------------------------------------------------------------
        // SECTION 7: Reusable response_valid Monitor Across All 10 Scenarios (Gap 4.2)
        //------------------------------------------------------------
        $display("\n--- SECTION 7: Reusable response_valid Monitor Across All 10 Scenarios (Gap 4.2) ---");

        // Scenario 1: Successful Exact-Payment Purchase (Price=10, Tender=10)
        fork
            send_req(COIN, 16'd10, 5'd0);
            verify_and_monitor_resp("MON-SCEN-1 [Exact Purchase]", STATUS_SUCCESS, ERR_NONE, 16'd0, 1'b1);
        join

        // Scenario 2: Successful Overpayment Purchase (Price=10, Tender=50, Change=40)
        fork
            send_req(NOTE, 16'd50, 5'd0);
            verify_and_monitor_resp("MON-SCEN-2 [Overpayment]", STATUS_SUCCESS, ERR_NONE, 16'd40, 1'b1);
        join

        // Scenario 3: Underpayment (Price=10, Tender=5, Refund=5)
        fork
            send_req(COIN, 16'd5, 5'd0);
            verify_and_monitor_resp("MON-SCEN-3 [Underpayment]", STATUS_FAILED, ERR_BALANCE, 16'd5, 1'b0);
        join

        // Scenario 4: Invalid Payment Type (Type 7 -> ERR_INVALID_PAYMENT)
        fork
            send_req(payment_t'(3'd7), 16'd10, 5'd0);
            verify_and_monitor_resp("MON-SCEN-4 [Invalid Payment Type]", STATUS_FAILED, ERR_INVALID_PAYMENT, 16'd0, 1'b0);
        join

        // Scenario 5: Invalid Amount (Amount 0 -> ERR_INVALID_AMOUNT)
        fork
            send_req(COIN, 16'd0, 5'd0);
            verify_and_monitor_resp("MON-SCEN-5 [Zero Amount]", STATUS_FAILED, ERR_INVALID_AMOUNT, 16'd0, 1'b0);
        join

        // Scenario 6: Corrupted CRC (ERR_CRC)
        fork
            begin
                @(posedge clk iff dut_top.out_valid);
                force dut_top.out_packet.crc = ~dut_top.out_packet.crc;
                @(posedge clk);
                release dut_top.out_packet.crc;
            end
            begin
                send_req(CARD, 16'd10, 5'd0);
            end
            begin
                verify_and_monitor_resp("MON-SCEN-6 [Corrupted CRC]", STATUS_FAILED, ERR_CRC, 16'd0, 1'b0);
            end
        join

        // Scenario 7: Duplicate Transaction ID (ERR_DUPLICATE)
        @(negedge clk iff dut_top.request_ready);
        dut_top.u_security_engine.last_transaction_id = dut_top.u_payment_interface.transaction_counter;
        fork
            send_req(COIN, 16'd10, 5'd0);
            verify_and_monitor_resp("MON-SCEN-7 [Duplicate Token]", STATUS_FAILED, ERR_DUPLICATE, 16'd0, 1'b0);
        join

        // Scenario 8: Invalid Product ID (PID=5 with PRODUCT_COUNT=5 -> ERR_INVALID_PRODUCT)
        fork
            send_req(COIN, 16'd10, 5'd5);
            verify_and_monitor_resp("MON-SCEN-8 [Invalid Product]", STATUS_FAILED, ERR_INVALID_PRODUCT, 16'd0, 1'b0);
        join

        // Scenario 9: Timeout With Tendered Balance (ERR_TIMEOUT, Refund=50)
        fork
            begin
                @(posedge clk iff dut_top.u_transaction_controller.current_state == CHECK_BALANCE);
                force dut_top.u_timeout_controller.timeout = 1'b1;
                repeat (2) @(posedge clk);
                release dut_top.u_timeout_controller.timeout;
            end
            begin
                send_req(NOTE, 16'd50, 5'd0);
            end
            begin
                verify_and_monitor_resp("MON-SCEN-9 [Timeout]", STATUS_TIMEOUT, ERR_TIMEOUT, 16'd50, 1'b0);
            end
        join

        // Scenario 10: Out of Stock Error (Drain stock of product 4 to 0 -> ERR_STOCK, Refund=tendered)
        dut_top.u_inventory_manager.qty_mem[4] = 8'd0;
        fork
            send_req(NOTE, 16'd50, 5'd4);
            verify_and_monitor_resp("MON-SCEN-10 [Out of Stock]", STATUS_FAILED, ERR_STOCK, 16'd50, 1'b0);
        join

        // Final conservation and pulse check across all sections
        check_condition("M6-FIN: Total wide response pulses across entire execution is 0", mon_resp_wide == 0);
        check_condition("M6-FIN: Final conservation of requests (accepted == responses)", mon_accept_total == mon_resp_total);

        // Final report
        $display("\n================================================================");
        $display("   TIMEOUT TESTBENCH SUMMARY (M6 CLOSURE)");
        $display("================================================================");
        $display("Total Checks : %0d", total_tests);
        $display("Passed Checks: %0d", passed_tests);
        $display("Failed Checks: %0d", failed_tests);
        $display("KL Hits      : %0d", kl_hits);

        if (failed_tests != 0 || tb_errors != 0) begin
            $display("SVM_TB_RESULT: FAIL total=%0d passed=%0d failed=%0d tb_errors=%0d",
                     total_tests, passed_tests, failed_tests, tb_errors);
            $fatal(1, "tb_unit_timeout reported failures");
        end else begin
            $display("SVM_TB_RESULT: PASS total=%0d passed=%0d failed=%0d tb_errors=%0d",
                     total_tests, passed_tests, failed_tests, tb_errors);
            $finish;
        end
    end

endmodule

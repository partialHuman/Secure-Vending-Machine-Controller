`timescale 1ns/1ps

module tb_unit_security;

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
            $display("[SEC_TEST PASS] %s", desc);
        end else begin
            failed_tests++;
            tb_errors++;
            $error("[SEC_TEST FAIL] %s", desc);
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
    // DUT: security_engine (PRODUCT_COUNT = 5)
    //------------------------------------------------------------
    logic packet_valid;
    transaction_packet_t packet;

    logic security_ok;
    error_t security_error;
    logic security_done;
    logic secure_valid;
    transaction_packet_t secure_packet;

    security_engine #(
        .PRODUCT_COUNT(5)
    ) dut_sec (
        .clk(clk),
        .rst(rst),
        .packet_valid(packet_valid),
        .packet(packet),
        .security_ok(security_ok),
        .security_error(security_error),
        .security_done(security_done),
        .secure_valid(secure_valid),
        .secure_packet(secure_packet)
    );

    // CRC-8 Generator for valid test stimulus
    localparam int PAYLOAD_WIDTH = PAYMENT_WIDTH + BALANCE_WIDTH + PRODUCT_ID_WIDTH + TRANSACTION_WIDTH;
    logic [PAYLOAD_WIDTH-1:0] crc_data_in;
    logic [7:0] calculated_crc;

    crc8 #(
        .DATA_WIDTH(PAYLOAD_WIDTH)
    ) u_crc_gen (
        .data_in(crc_data_in),
        .crc_out(calculated_crc)
    );

    logic   sampled_ok;
    error_t sampled_error;
    logic   sampled_done;

    task automatic send_packet(
        input logic [PAYMENT_WIDTH-1:0] p_type,
        input logic [15:0] amt,
        input logic [4:0] pid,
        input logic [15:0] tid,
        input bit corrupt_crc
    );
    begin
        crc_data_in = {p_type, amt, pid, tid};
        #1;
        @(negedge clk);
        packet.payment_type   = payment_t'(p_type);
        packet.amount         = amt;
        packet.product_id     = pid;
        packet.transaction_id = tid;
        packet.crc            = corrupt_crc ? ~calculated_crc : calculated_crc;
        packet_valid          = 1'b1;
        @(posedge clk);
        #1;
        sampled_ok    = security_ok;
        sampled_error = security_error;
        sampled_done  = security_done;
        packet_valid  = 1'b0;
        @(posedge clk);
        #1;
    end
    endtask

    //------------------------------------------------------------
    // Main Test Sequence
    //------------------------------------------------------------
    initial begin
        packet_valid  = 1'b0;
        packet        = '0;
        crc_data_in   = '0;
        sampled_ok    = 1'b0;
        sampled_error = ERR_NONE;
        sampled_done  = 1'b0;

        // Reset
        rst = 1'b1;
        #30;
        @(negedge clk);
        rst = 1'b0;
        @(posedge clk);
        #1;

        $display("================================================================");
        $display("   SECURITY ENGINE DIRECT UNIT TESTBENCH (KL-004, RTL-006) (M1)");
        $display("================================================================");

        //------------------------------------------------------------
        // SECTION 1: Valid Baseline Payment Types (0 to 5)
        //------------------------------------------------------------
        $display("\n--- SECTION 1: Legal Payment Types (0 to 5) ---");
        send_packet(3'd0, 16'd10, 5'd0, 16'd1, 0); // COIN
        check_condition("SEC-PT0: COIN valid accepted", sampled_ok == 1'b1 && sampled_error == ERR_NONE);

        send_packet(3'd1, 16'd10, 5'd1, 16'd2, 0); // NOTE
        check_condition("SEC-PT1: NOTE valid accepted", sampled_ok == 1'b1 && sampled_error == ERR_NONE);

        send_packet(3'd2, 16'd10, 5'd2, 16'd3, 0); // RFID
        check_condition("SEC-PT2: RFID valid accepted", sampled_ok == 1'b1 && sampled_error == ERR_NONE);

        send_packet(3'd3, 16'd10, 5'd3, 16'd4, 0); // CARD (<=5000)
        check_condition("SEC-PT3: CARD valid accepted", sampled_ok == 1'b1 && sampled_error == ERR_NONE);

        send_packet(3'd4, 16'd10, 5'd4, 16'd5, 0); // UPI
        check_condition("SEC-PT4: UPI valid accepted", sampled_ok == 1'b1 && sampled_error == ERR_NONE);

        send_packet(3'd5, 16'd10, 5'd0, 16'd6, 0); // WALLET
        check_condition("SEC-PT5: WALLET valid accepted", sampled_ok == 1'b1 && sampled_error == ERR_NONE);

        //------------------------------------------------------------
        // SECTION 2: Undefined Payment Types (KL-004) with Valid CRC
        //------------------------------------------------------------
        $display("\n--- SECTION 2: Undefined Payment Types 6 and 7 (KL-004) ---");
        // Payment type 6 with valid CRC
        send_packet(3'd6, 16'd10, 5'd0, 16'd7, 0);
        check_condition("SEC-PT6: Type 6 rejected with ERR_INVALID_PAYMENT",
                        sampled_ok == 1'b0 && sampled_error == ERR_INVALID_PAYMENT);

        // Payment type 7 with valid CRC
        send_packet(3'd7, 16'd10, 5'd0, 16'd8, 0);
        check_condition("SEC-PT7: Type 7 rejected with ERR_INVALID_PAYMENT",
                        sampled_ok == 1'b0 && sampled_error == ERR_INVALID_PAYMENT);

        //------------------------------------------------------------
        // SECTION 3: Zero-Amount Disambiguation & Precedence (RTL-006)
        //------------------------------------------------------------
        $display("\n--- SECTION 3: Zero-Amount Precedence (RTL-006) ---");
        // COIN with amount 0
        send_packet(3'd0, 16'd0, 5'd0, 16'd9, 0);
        check_condition("SEC-ZA: Amount 0 rejected with ERR_INVALID_AMOUNT",
                        sampled_ok == 1'b0 && sampled_error == ERR_INVALID_AMOUNT);

        // CARD with amount 0 (verify precedence over Card Auth Limit > 5000)
        send_packet(3'd3, 16'd0, 5'd0, 16'd10, 0);
        check_condition("SEC-ZA-CARD: Amount 0 rejected on card with ERR_INVALID_AMOUNT",
                        sampled_ok == 1'b0 && sampled_error == ERR_INVALID_AMOUNT);
        check_condition("SEC-ZA-CARD: Zero amount precedence over ERR_AUTH", sampled_error != ERR_AUTH);

        // CARD with amount > 5000 (Auth Limit)
        send_packet(3'd3, 16'd5001, 5'd0, 16'd11, 0);
        check_condition("SEC-AUTH: Card > 5000 rejected with ERR_AUTH", sampled_ok == 1'b0 && sampled_error == ERR_AUTH);

        // CARD with amount == 5000 (Boundary OK)
        send_packet(3'd3, 16'd5000, 5'd0, 16'd12, 0);
        check_condition("SEC-AUTH: Card == 5000 accepted", sampled_ok == 1'b1 && sampled_error == ERR_NONE);

        //------------------------------------------------------------
        // SECTION 4: Product ID Bounds & Integrity
        //------------------------------------------------------------
        $display("\n--- SECTION 4: Product Bounds, CRC, and Duplicate Rejection ---");
        // Product ID 4 (valid, max index for N=5)
        send_packet(3'd0, 16'd10, 5'd4, 16'd13, 0);
        check_condition("SEC-BOUND: Product ID 4 accepted", sampled_ok == 1'b1);

        // Product ID 5 (invalid boundary for N=5)
        send_packet(3'd0, 16'd10, 5'd5, 16'd14, 0);
        check_condition("SEC-BOUND: Product ID 5 rejected with ERR_INVALID_PRODUCT",
                        sampled_ok == 1'b0 && sampled_error == ERR_INVALID_PRODUCT);

        // Product ID 31 (maximum 5-bit out of range)
        send_packet(3'd0, 16'd10, 5'd31, 16'd15, 0);
        check_condition("SEC-BOUND: Product ID 31 rejected with ERR_INVALID_PRODUCT",
                        sampled_ok == 1'b0 && sampled_error == ERR_INVALID_PRODUCT);

        // Corrupted CRC
        send_packet(3'd0, 16'd10, 5'd0, 16'd16, 1);
        check_condition("SEC-CRC: Corrupted CRC rejected with ERR_CRC",
                        sampled_ok == 1'b0 && sampled_error == ERR_CRC);

        // Duplicate Transaction ID
        send_packet(3'd0, 16'd10, 5'd0, 16'd17, 0); // initial
        check_condition("SEC-DUP: First transaction ID accepted", sampled_ok == 1'b1);
        send_packet(3'd0, 16'd10, 5'd0, 16'd17, 0); // duplicate
        check_condition("SEC-DUP: Consecutive identical ID rejected with ERR_DUPLICATE",
                        sampled_ok == 1'b0 && sampled_error == ERR_DUPLICATE);

        // Final Summary
        $display("\n================================================================");
        $display("   SECURITY TESTBENCH SUMMARY");
        $display("================================================================");
        $display("Total Checks : %0d", total_tests);
        $display("Passed Checks: %0d", passed_tests);
        $display("Failed Checks: %0d", failed_tests);
        $display("KL Hits      : %0d", kl_hits);

        if (failed_tests != 0 || tb_errors != 0) begin
            $display("SVM_TB_RESULT: FAIL total=%0d passed=%0d failed=%0d tb_errors=%0d",
                     total_tests, passed_tests, failed_tests, tb_errors);
            $fatal(1, "tb_unit_security reported failures");
        end else begin
            $display("SVM_TB_RESULT: PASS total=%0d passed=%0d failed=%0d tb_errors=%0d",
                     total_tests, passed_tests, failed_tests, tb_errors);
            $finish;
        end
    end

endmodule

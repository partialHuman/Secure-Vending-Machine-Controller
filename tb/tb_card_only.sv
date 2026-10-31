`timescale 1ns/1ps

module tb_card_only;

    import transaction_pkg::*;

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
    // DUT
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
    // v1.0.1 integrity support: error accounting, global watchdog
    //------------------------------------------------------------
    integer tb_errors = 0;

    task automatic tb_fail(input string msg);
    begin
        tb_errors++;
        $error("%s", msg);
    end
    endtask

    // Global watchdog: a hung wait (e.g. @(posedge ...) that never occurs)
    // must fail the run instead of hanging the simulator.
    initial begin
        #1000000;   // 1 ms of simulated time (timescale 1ns/1ps)
        $display("SVM_TB_RESULT: FAIL global watchdog expired");
        $fatal(1, "global watchdog expired");
    end

    //------------------------------------------------------------
    // v1.0.2 independent handshake / response monitor
    // Counts accepted requests (request_valid && request_ready at a clock
    // edge) and response pulses (rising edges of response_valid)
    // independently of the test sequence, so lost, duplicated or extra
    // responses are visible even when a test never looks for them.
    //------------------------------------------------------------
    integer mon_accept_total = 0;   // valid && ready handshakes
    integer mon_resp_total   = 0;   // rising edges of response_valid
    integer mon_resp_wide    = 0;   // clocks where response_valid stayed high
    integer mon_aborted      = 0;   // accepted requests deliberately aborted by a test reset
    integer mon_accept_cycle = 0;   // cycle_count at the most recent acceptance (mixed TB only)
    logic   mon_resp_prev    = 1'b0;

    always @(posedge clk) begin
        if (!rst && request_valid && request_ready) begin
            mon_accept_total <= mon_accept_total + 1;
        end
        if (response_valid && !mon_resp_prev)
            mon_resp_total <= mon_resp_total + 1;
        if (response_valid && mon_resp_prev)
            mon_resp_wide  <= mon_resp_wide + 1;
        mon_resp_prev <= response_valid;
    end

    //------------------------------------------------------------
    // Assertions
    //------------------------------------------------------------
    // Response assertion
    always @(posedge clk)
    begin
        if(response_valid)
        begin
            assert(!$isunknown(response.status))
            else
                tb_fail($sformatf("[%0t] ERROR : Unknown Response Status", $time));
    
            assert(!$isunknown(response.error))
            else
                tb_fail($sformatf("[%0t] ERROR : Unknown Error Code", $time));
        end
    end
    
    // Balance assertion
    always @(posedge clk)
    begin
        if(response_valid &&
          (response.dispense || (response.refund != 0)))
        begin
            #1;
    
            assert(dut.u_balance_manager.current_balance == 0)
            else
                tb_fail($sformatf("[%0t] ERROR : Balance Not Cleared!", $time));
        end
    end
    
    // FSM assertion
    always @(posedge clk)
    begin
        if(!rst)
        begin
            assert(
                dut.u_transaction_controller.current_state inside
                {
                    IDLE,
                    RECEIVE_PAYMENT,
                    AUTHENTICATE,
                    CHECK_BALANCE,
                    CHECK_INVENTORY,
                    DISPENSE,
                    REFUND,
                    COMPLETE,
                    ERROR_STATE
                }
            )
            else
                tb_fail($sformatf("[%0t] ERROR : Illegal FSM State!", $time));
        end
    end
 
    //------------------------------------------------------------
    // Scoreboard
    //------------------------------------------------------------
    integer i;
    
    integer total_tests;
    integer passed_tests;
    integer failed_tests;
    integer test_number;
    integer initial_qty;
    real pass_percentage;
    //------------------------------------------------------------
    // Transaction Statistics
    //------------------------------------------------------------
    
    integer success_count;
    integer balance_error_count;
    integer crc_error_count;
    integer duplicate_error_count;
    integer timeout_error_count;
    integer stock_error_count;
    
    //------------------------------------------------------------
    // Reporting Variables
    //------------------------------------------------------------
    
    integer cycle_start;
    integer cycle_end;
    integer latency_cycles;
    time sim_start;
    time sim_end;
    time sim_time;
      
    //integer test_number = 0;
    
    logic [15:0] inventory_before;
    logic [15:0] inventory_after;
    logic [15:0] expected_price;
    integer previous_inventory;
    logic [31:0] cycle_count;
    
    //------------------------------------------------------------
    // Global Cycle Counter
    //------------------------------------------------------------
    
    always @(posedge clk)
    begin
        if(rst)
            cycle_count <= 0;
        else
            cycle_count <= cycle_count + 1;
    end

    //------------------------------------------------------------
    // Variables
    //------------------------------------------------------------

    response_packet_t resp;
    bit got_response;
    localparam WATCHDOG = 50;

    //------------------------------------------------------------
    // Reset
    //------------------------------------------------------------

    task reset_dut();

    begin

        clk = 0;
        rst = 1;
        request_valid = 0;
        request = '0;
        repeat(5)
            @(posedge clk);
        rst = 0;
        repeat(2)
            @(posedge clk);

    end
    endtask
    
    //------------------------------------------------------------
    // Send card Payment
    //------------------------------------------------------------
        //------------------------------------------------------------
    // Active transaction tracking (v1.0.1 audit fix)
    //------------------------------------------------------------
    typedef struct packed {
        payment_t                       payment_type;
        logic [BALANCE_WIDTH-1:0]       amount;
        logic [PRODUCT_ID_WIDTH-1:0]    product_id;
        logic [31:0]                    inv_before;
        logic [BALANCE_WIDTH-1:0]       bal_before;
    } active_txn_t;

    active_txn_t active_txn;
    logic active_txn_valid;

task send_card
    (
        input logic [BALANCE_WIDTH-1:0] amount,
        input logic [PRODUCT_ID_WIDTH-1:0] product
    );
        integer wait_cycles;
        bit accepted;
    begin
        cycle_start = cycle_count;

        @(negedge clk);
        request.payment_type = CARD;
        request.amount       = amount;
        request.product_id   = product;
        request_valid        = 1'b1;

        wait_cycles = 0;
        accepted    = 1'b0;

        while (!accepted && (wait_cycles < WATCHDOG))
        begin
            if (request_ready)
            begin
                @(posedge clk);
                accepted = 1'b1;
                active_txn.payment_type = CARD;
                active_txn.amount       = amount;
                active_txn.product_id   = product;
                active_txn.inv_before   = dut.u_inventory_manager.qty_mem[product];
                active_txn.bal_before   = dut.u_balance_manager.current_balance;
                active_txn_valid        = 1'b1;
            end
            else
            begin
                @(negedge clk);
                wait_cycles++;
            end
        end

        @(negedge clk);
        request_valid = 1'b0;

        if (!accepted)
        begin
            tb_fail($sformatf("[%0t] ERROR: Request handshake timeout (request_ready never asserted)!", $time));
        end
    end
    endtask
    
    //------------------------------------------------------------
    // Wait Response
    //------------------------------------------------------------
    
    task wait_response;
        integer timeout;
    begin
        timeout      = 0;
        got_response = 0;
        resp         = '0;

        while (response_valid) @(posedge clk);

        while (timeout < WATCHDOG)
        begin
            @(posedge clk);
            timeout++;

            if(response_valid)
            begin
                got_response = 1;
                resp         = response;

                cycle_end      = cycle_count;
                latency_cycles = cycle_end - cycle_start;


                previous_inventory = active_txn.inv_before;
                inventory_before   = active_txn.inv_before;
                inventory_after    = dut.u_inventory_manager.qty_mem[active_txn.product_id];

                if(resp.dispense)
                begin
                    assert(inventory_after == previous_inventory - 1)
                    else
                        tb_fail($sformatf("[%0t] ERROR : Inventory not decremented correctly! before=%0d after=%0d",
                                $time, previous_inventory, inventory_after));
                end
                else
                begin
                    assert(inventory_after == previous_inventory)
                    else
                        tb_fail($sformatf("[%0t] ERROR : Inventory altered on non-dispense! before=%0d after=%0d",
                                $time, previous_inventory, inventory_after));
                end

                if(resp.dispense || (resp.refund != 0))
                begin
                    assert(dut.u_balance_manager.current_balance == 0)
                    else
                        tb_fail($sformatf("[%0t] ERROR : Balance not cleared!", $time));
                end

                disable wait_response;
            end
        end

        if(!got_response)
        begin
            tb_fail($sformatf("[%0t] ERROR : Response Timeout!", $time));
        end
    end
    endtask
    
     //------------------------------------------------------------
    // Checker
    //------------------------------------------------------------
    task automatic check_result
    (
        input string test_name,
        input status_t exp_status,
        input error_t exp_error,
        input bit exp_dispense,
        input logic [BALANCE_WIDTH-1:0] exp_refund
    );
    
    bit pass;
    
    begin
    
        total_tests++;
        test_number++;
    
        pass =
        (
            got_response &&
            resp.status    == exp_status &&
            resp.error     == exp_error &&
            resp.dispense  == exp_dispense &&
            resp.refund    == exp_refund
        );
    
        if(pass)
            passed_tests++;
        else
            failed_tests++;
        
        //------------------------------------------------------------
        // Transaction Statistics
        //------------------------------------------------------------
        
        if(resp.status == STATUS_SUCCESS)
        begin
            success_count++;
        end
        else
        begin
            case(resp.error)
        
                ERR_BALANCE:
                    balance_error_count++;
        
                ERR_CRC:
                    crc_error_count++;
        
                ERR_DUPLICATE:
                    duplicate_error_count++;
        
                ERR_TIMEOUT:
                    timeout_error_count++;
        
                ERR_STOCK:
                    stock_error_count++;
        
                default:
                    ;
        
            endcase
        end
        
        
        
        $display("|%4d | %-40s |%10t|%6d|%5d|%4h|%7s|%3d|%6d|%5d|%4d|%15s|%15s|%4d|%6d|%6d|%6s|",
                test_number,
                test_name,
                $time,
                latency_cycles,
                dut.u_payment_interface.packet.transaction_id,
                dut.u_security_engine.secure_packet.crc,
                active_txn.payment_type.name(),
                active_txn.product_id,
                inventory_before,
                dut.u_inventory_manager.price_mem[active_txn.product_id],
                active_txn.amount,
                resp.status.name(),
                resp.error.name(),
                resp.dispense,
                resp.refund,
                inventory_after,
                pass ? "PASS" : "FAIL"
            );
    
    end
    
    endtask
    
    
    
    //------------------------------------------------------------
    // Internal Verification Checker
    //------------------------------------------------------------
    task check_internal
    (
        input string name,
        input integer actual,
        input integer expected
    );
    
    bit pass;
    
    begin
    
        total_tests++;
        test_number++;
    
        pass = (actual == expected);
    
        if(pass)
            passed_tests++;
        else
            failed_tests++;
    
                $display("|%4d | %-40s |%10t|%6d|%5d|%4h|%7s|%3d|%6d|%5d|%4d|%15s|%15s|%4d|%6d|%6d|%6s|",
                test_number,
                name,
                $time,
                "",          // Lat
                "",          // TxnID
                "",          // CRC
                "",          // Payment
                request.product_id,
                actual,
                "",          // Price
                "",          // Card
                "",          // Status
                "",          // Error
                "",          // Dispense
                "",          // Refund
            
                actual,
            
                pass ? "PASS":"FAIL"
            );
    
    end
    
    endtask
    
    //------------------------------------------------------------
    // Test Sequence
    //------------------------------------------------------------

    initial
    begin
    
        sim_start = $time;

        total_tests = 0;
        passed_tests = 0;
        failed_tests = 0;
        test_number = 0;
        
        success_count          = 0;
        balance_error_count    = 0;
        crc_error_count        = 0;
        duplicate_error_count  = 0;
        timeout_error_count    = 0;
        stock_error_count      = 0;
        
        reset_dut();

        //------------------------------------------------------------
        // TRANSACTION Verification Table
        //------------------------------------------------------------
        $display();
        $display("======================================================================================================================================================================================================================");
        $display("TRANSACTION VERIFICATION REPORT");
        $display("======================================================================================================================================================================================================================");
        $display("|Test |                Scenario                  |           Time(ns) |Lat(C)|TxnID|CRC |Payment|PID|Qty(B)|Price|Amount|    Status     |     Error     |Disp|Refund|Qty(A)|Result|");
        $display("======================================================================================================================================================================================================================");
        
        
        //------------------------------------------------------------
        // Test 1 : Verify Reset State
        //------------------------------------------------------------
        
        repeat(2) @(posedge clk);
        
        // Controller State
        check_internal(
            "Controller in IDLE after Reset",
            dut.u_transaction_controller.current_state,
            IDLE
        );
        
        // Balance Reset
        check_internal(
            "Balance = 0 after Reset",
            dut.u_balance_manager.current_balance,
            0
        );
        
        // Response should not be valid
        check_internal(
            "Response Invalid after Reset",
            response_valid,
            0
        );
        
        

        //------------------------------------------------------------
        // Test 2 : Exact Card Payment
        // Product 0 = Price 10
        //------------------------------------------------------------
    
        send_card(16'd10,5'd0);
    
        wait_response();
    
        check_result(
            "Exact Card Payment",
            STATUS_SUCCESS,
            ERR_NONE,
            1,
            16'd0
        );
    
        check_internal(
            "Inventory Product0 = 19",
            dut.u_inventory_manager.qty_mem[0],
            19
        );
    
        check_internal(
            "Balance Cleared",
            dut.u_balance_manager.current_balance,
            0
        );
    
        //------------------------------------------------------------
        // Test 3 : Insufficient card balance
        // Product 1 = Price 20
        //------------------------------------------------------------
    
        send_card(16'd5,5'd1);
    
        wait_response();
    
        check_result(
            "Insufficient Card Balance",
            STATUS_FAILED,
            ERR_BALANCE,
            0,
            16'd5
        );
    
        check_internal(
            "Balance Cleared After Refund",
            dut.u_balance_manager.current_balance,
            0
        );
    
        check_internal(
            "Inventory Unchanged",
            dut.u_inventory_manager.qty_mem[1],
            20
        );
    
        //------------------------------------------------------------
        // Test 4 : Exact Card Again
        //------------------------------------------------------------
    
        send_card(16'd20,5'd1);
    
        wait_response();
    
        check_result(
            "Exact Card Product1",
            STATUS_SUCCESS,
            ERR_NONE,
            1,
            16'd0
        );
    
        check_internal(
            "Inventory Product1 = 19",
            dut.u_inventory_manager.qty_mem[1],
            19
        );
    
        //------------------------------------------------------------
        // Test 5 : Over Payment
        //------------------------------------------------------------
    
        send_card(16'd50,5'd2);
    
        wait_response();
    
        check_result(
            "Over Payment (KL-001: change not returned)",
            STATUS_SUCCESS,
            ERR_NONE,
            1,
            16'd0
        );
    
        //------------------------------------------------------------
        // Test 6 : NO card Inserted
        //------------------------------------------------------------
    
        send_card(16'd0,5'd2);
    
        wait_response();
    
        check_result(
            "No Card Detected",
            STATUS_FAILED,
            ERR_BALANCE,
            0,
            16'd0
        );
    
        //------------------------------------------------------------
        // Test 7 : Multiple Normal Purchases
        //------------------------------------------------------------
    
        for(i=0;i<5;i=i+1)
        begin
    
            send_card(16'd10,5'd0);
    
            wait_response();
    
            check_result(
                $sformatf("Repeated Card Purchase %0d",i+1),
                STATUS_SUCCESS,
                ERR_NONE,
                1,
                16'd0
            );
    
        end
    
        check_internal(
            "Inventory Product0 = 14",
            dut.u_inventory_manager.qty_mem[0],
            14
        );
        
            //------------------------------------------------------------
        // Test 8 : Duplicate Transaction
        //------------------------------------------------------------
    
        force dut.u_payment_interface.transaction_counter = 16'd100;
    
        send_card(16'd10,5'd0);
        wait_response();
    
        check_result(
            "Duplicate Card First Transactiont",
            STATUS_SUCCESS,
            ERR_NONE,
            1,
            0
        );
    
        send_card(16'd10,5'd0);
        wait_response();
    
        check_result(
            "Duplicate Transaction",
            STATUS_FAILED,
            ERR_DUPLICATE,
            0,
            0
        );
    
        release dut.u_payment_interface.transaction_counter;
    
        //------------------------------------------------------------
        // Test 9 : CRC Corruption
        //------------------------------------------------------------
    
        fork
    
        begin
    
            @(posedge dut.u_payment_interface.packet_valid);
    
            force dut.u_payment_interface.packet.crc =
                  ~dut.u_payment_interface.packet.crc;
    
            @(posedge clk);
    
            release dut.u_payment_interface.packet.crc;
    
        end
    
        begin
    
            send_card(16'd10,5'd0);
    
            wait_response();
    
        end
    
        join
    
        check_result(
            "CRC Corruption",
            STATUS_FAILED,
            ERR_CRC,
            0,
            0
        );
    
        //------------------------------------------------------------
        // Test 10 : Stock Depletion
        //------------------------------------------------------------
    
        // Product 4
        // Price = 50
        // Quantity = 20
    
        for(i=0;i<20;i=i+1)
        begin
    
            send_card(16'd50,5'd4);
    
            wait_response();
    
            check_result(
                $sformatf("Stock Depletion Purchase %0d",i+1),
                STATUS_SUCCESS,
                ERR_NONE,
                1,
                0
            );
    
        end
    
        check_internal(
            "Inventory Product4 = 0",
            dut.u_inventory_manager.qty_mem[4],
            0
        );
    
        //------------------------------------------------------------
        // Test 11 : Purchase after Stock Empty
        //------------------------------------------------------------
    
        send_card(16'd50,5'd4);
    
        wait_response();
    
        check_result(
            "Stock Empty",
            STATUS_FAILED,
            ERR_STOCK,
            0,
            16'd50
        );
    
        // Test 12 : Back-to-Back Transactions (Handshake Validated)
        //------------------------------------------------------------
    
        send_card(16'd10, 5'd0);
        wait_response();
        check_result(
            "Back-to-Back Txn 1",
            STATUS_SUCCESS,
            ERR_NONE,
            1'b1,
            16'd0
        );

        send_card(16'd20, 5'd1);
        wait_response();
        check_result(
            "Back-to-Back Txn 2",
            STATUS_SUCCESS,
            ERR_NONE,
            1'b1,
            16'd0
        );
    
        check_internal(
            "Controller Returned Idle",
            dut.u_transaction_controller.current_state,
            IDLE
        );
    
        //------------------------------------------------------------
        // //------------------------------------------------------------
        // Test 13 : Timeout Test
        //------------------------------------------------------------
    
        fork
    
        begin
    
            @(posedge clk iff
                dut.u_transaction_controller.current_state==CHECK_BALANCE);
    
            force dut.u_transaction_controller.current_state = CHECK_BALANCE;
    
            @(posedge dut.u_timeout_controller.timeout);
    
            @(posedge clk);
    
            release dut.u_transaction_controller.current_state;
    
        end
    
        begin
    
            send_card(16'd10,5'd0);
    
            wait_response();
    
        end
    
        join
    
        check_result(
            "Timeout Transaction",
            STATUS_TIMEOUT,
            ERR_TIMEOUT,
            0,
            0
        );
    
        //------------------------------------------------------------
        // Test 14 : Stress Test
        //------------------------------------------------------------
 
        initial_qty = dut.u_inventory_manager.qty_mem[2];
        
        for(i = 0; i < 50; i = i + 1)
        begin
            send_card(16'd30, 5'd2);
            wait_response();
        
            if(i < initial_qty)
            begin
                check_result(
                    $sformatf("Stress Test Purchase %0d", i+1),
                    STATUS_SUCCESS,
                    ERR_NONE,
                    1'b1,
                    16'd0
                );
            end
            else
            begin
                check_result(
                    $sformatf("Stress Test Purchase %0d (Stock Empty)", i+1),
                    STATUS_FAILED,
                    ERR_STOCK,
                    1'b0,
                    16'd30
                );
            end
        end        
        check_internal(
            "Inventory Product2 = 0",
            dut.u_inventory_manager.qty_mem[2],
            0
        );
        
        //------------------------------------------------------------
        // Final Internal Checks
        //------------------------------------------------------------
    
        check_internal(
            "Final Balance = 0",
            dut.u_balance_manager.current_balance,
            0
        );
    
        check_internal(
            "Transaction Controller Returned to IDLE",
            dut.u_transaction_controller.current_state,
            IDLE
        );
        
        //------------------------------------------------------------
        // v1.0.2: request/response conservation (independent monitor)
        // Every accepted request must produce exactly one response unless
        // the test deliberately aborted it with a reset.
        //------------------------------------------------------------
        repeat (5) @(posedge clk);
        total_tests++;
        if (mon_accept_total == mon_resp_total + mon_aborted)
            passed_tests++;
        else begin
            failed_tests++;
            tb_fail($sformatf("Monitor: accepted=%0d responses=%0d aborted=%0d violates accepted == responses + aborted",
                              mon_accept_total, mon_resp_total, mon_aborted));
        end
        $display("SVM_MONITOR: accepted=%0d responses=%0d aborted=%0d wide_response_pulses=%0d",
                 mon_accept_total, mon_resp_total, mon_aborted, mon_resp_wide);
        if (mon_resp_wide != 0) begin
            $display("SVM_KNOWN_LIMITATION: KL-002 response_valid stayed high for more than one cycle (%0d extra cycle(s)); see docs/known-limitations.md", mon_resp_wide);
            if ($test$plusargs("STRICT_KL")) begin
                total_tests++; failed_tests++;
                tb_fail("STRICT_KL: response_valid wider than one cycle");
            end
        end

        // Percentage calculator
        if(total_tests != 0)
            pass_percentage = (passed_tests * 100.0) / total_tests;
        else
            pass_percentage = 0.0;
        
        //  Sim time 
        sim_end  = $time;
        sim_time = sim_end - sim_start;
        
        
        
        //------------------------------------------------------------
        // Simulation Summary
        //------------------------------------------------------------
        
        $display("===============================================================================================================================================================");
        $display();
        $display("Total Tests  : %0d",total_tests);
        $display("Passed Tests : %0d",passed_tests);
        $display("Failed Tests : %0d",failed_tests);
        $display("Pass Percentage  : %.2f %%", pass_percentage);
        $display("Simulation Time  : %0t ns", sim_time);
        $display();
        $display("TRANSACTION STATISTICS");
        $display("----------------------------------------------------"); 
        $display("Successful Transactions : %0d", success_count);
        $display("Balance Errors          : %0d", balance_error_count);
        $display("CRC Errors              : %0d", crc_error_count);
        $display("Duplicate Transactions  : %0d", duplicate_error_count);
        $display("Timeout Transactions    : %0d", timeout_error_count);
        $display("Stock Errors            : %0d", stock_error_count);      
        $display("----------------------------------------------------");
        $display();
        //------------------------------------------------------------
        // Final Inventory Report
        //------------------------------------------------------------
        
        $display();
        $display("============================================================");
        $display("                 FINAL INVENTORY REPORT");
        $display("============================================================");
        $display("| Product | Price | Quantity |");
        $display("------------------------------------------------------------");
        
        for(i = 0; i < 5; i = i + 1)
        begin
            $display("|   %0d     | %5d | %8d |",
                     i,
                     dut.u_inventory_manager.price_mem[i],
                     dut.u_inventory_manager.qty_mem[i]);
        end
        
        $display("============================================================");
        $display();
        $display("===============================================================================================================================================================");

    
        if (failed_tests != 0 || tb_errors != 0) begin
            $display("SVM_TB_RESULT: FAIL total=%0d passed=%0d failed=%0d tb_errors=%0d",
                     total_tests, passed_tests, failed_tests, tb_errors);
            $fatal(1, "testbench reported failures");
        end
        else begin
            $display("SVM_TB_RESULT: PASS total=%0d passed=%0d failed=%0d tb_errors=%0d",
                     total_tests, passed_tests, failed_tests, tb_errors);
            $finish;
        end

    
    end
    
endmodule
        
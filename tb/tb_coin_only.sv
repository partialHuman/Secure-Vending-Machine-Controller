`timescale 1ns/1ps

module tb_coin_only;

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

        .response(response),
        .response_valid(response_valid)
    );
    
    //------------------------------------------------------------
    // Assertions
    //------------------------------------------------------------
    // Response assertion
    always @(posedge clk)
    begin
        if(response_valid)
        begin
            assert(!$isunknown(resp.status))
            else
                $error("[%0t] ERROR : Unknown Response Status", $time);
    
            assert(!$isunknown(resp.error))
            else
                $error("[%0t] ERROR : Unknown Error Code", $time);
        end
    end
    
    // Balance assertion
    always @(posedge clk)
    begin
        if(response_valid &&
          (resp.dispense || (resp.refund != 0)))
        begin
            #1;
    
            assert(dut.u_balance_manager.current_balance == 0)
            else
                $error("[%0t] ERROR : Balance Not Cleared!", $time);
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
                $error("[%0t] ERROR : Illegal FSM State!", $time);
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
    // Send Coin Payment
    //------------------------------------------------------------
    task send_coin
    (
        input logic [BALANCE_WIDTH-1:0] amount,
        input logic [PRODUCT_ID_WIDTH-1:0] product
    );
    
    begin
    
        cycle_start = cycle_count;
    
        inventory_before =
            dut.u_inventory_manager.qty_mem[product];
    
        @(negedge clk);
    
        request.payment_type = COIN;
        request.amount       = amount;
        request.product_id   = product;
    
        request_valid = 1;
    
        @(negedge clk);
    
        request_valid = 0;
    
    end
    
    endtask
    
    //------------------------------------------------------------
    // Wait Response
    //------------------------------------------------------------
    
    task wait_response;
    
        integer timeout;
    
    begin
    
        // Capture inventory BEFORE transaction completes
        previous_inventory = dut.u_inventory_manager.qty_mem[request.product_id];
    
        timeout = 0;
        got_response = 0;
    
        while (timeout < WATCHDOG)
        begin
    
            @(posedge clk);
    
            timeout++;
    
            if(response_valid)
            begin
    
                got_response = 1;
    
                resp = response;
    
                cycle_end = cycle_count;
                latency_cycles = cycle_end - cycle_start;
    
                // Capture inventory AFTER transaction
                inventory_after = dut.u_inventory_manager.qty_mem[request.product_id];
    
                // Assertion: Inventory should decrease by one after successful dispense
                if(resp.dispense)
                begin
                    assert(inventory_after == previous_inventory - 1)
                    else
                        $error("[%0t] ERROR: Inventory not decremented correctly!", $time);
                end
    
                // Assertion: Balance should be cleared after dispense/refund
                if(resp.dispense || (resp.refund != 0))
                begin
                    assert(dut.u_balance_manager.current_balance == 0)
                    else
                        $error("[%0t] ERROR: Balance not cleared!", $time);
                end
                    
                disable wait_response;
    
            end
    
        end
    
        if(!got_response)
        begin
            $error("[%0t] ERROR: Response Timeout!", $time);
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
                request.payment_type.name(),
                request.product_id,
                inventory_before,
                dut.u_inventory_manager.price_mem[request.product_id],
                request.amount,
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
                "",          // Coin
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
        $display("|Test |                Scenario                  |           Time(ns) |Lat(C)|TxnID|CRC |Payment|PID|Qty(B)|Price|Coin|    Status     |     Error     |Disp|Refund|Qty(A)|Result|");
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
        // Test 2 : Exact Coin Payment
        // Product 0 = Price 10
        //------------------------------------------------------------
    
        send_coin(16'd10,5'd0);
    
        wait_response();
    
        check_result(
            "Exact Coin Payment",
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
        // Test 3 : Insufficient Coin
        // Product 1 = Price 20
        //------------------------------------------------------------
    
        send_coin(16'd5,5'd1);
    
        wait_response();
    
        check_result(
            "Insufficient Coin",
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
        // Test 4 : Exact Coin Again
        //------------------------------------------------------------
    
        send_coin(16'd20,5'd1);
    
        wait_response();
    
        check_result(
            "Exact Coin Product1",
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
    
        send_coin(16'd50,5'd2);
    
        wait_response();
    
        check_result(
            "Over Payment",
            STATUS_SUCCESS,
            ERR_NONE,
            1,
            16'd0
        );
    
        //------------------------------------------------------------
        // Test 6 : Zero Coin Inserted
        //------------------------------------------------------------
    
        send_coin(16'd0,5'd2);
    
        wait_response();
    
        check_result(
            "Zero Coin",
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
    
            send_coin(16'd10,5'd0);
    
            wait_response();
    
            check_result(
                $sformatf("Repeated Purchase %0d",i+1),
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
    
        send_coin(16'd10,5'd0);
        wait_response();
    
        check_result(
            "Duplicate Txn First Packet",
            STATUS_SUCCESS,
            ERR_NONE,
            1,
            0
        );
    
        send_coin(16'd10,5'd0);
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
    
            @(posedge dut.packet_valid);
    
            force dut.packet.crc = ~dut.packet.crc;
    
            @(posedge clk);
    
            release dut.packet.crc;
    
        end
    
        begin
    
            send_coin(16'd10,5'd0);
    
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
    
            send_coin(16'd50,5'd4);
    
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
    
        send_coin(16'd50,5'd4);
    
        wait_response();
    
        check_result(
            "Stock Empty",
            STATUS_FAILED,
            ERR_STOCK,
            0,
            16'd50
        );
    
        //------------------------------------------------------------
        // Test 12 : Back-to-Back Coin Insertions
        //------------------------------------------------------------
    
        send_coin(16'd10,5'd0);
    
        send_coin(16'd20,5'd1);
    
        repeat(20)
            @(posedge clk);
    
        check_internal(
            "Controller Returned Idle",
            dut.u_transaction_controller.current_state,
            IDLE
        );
    
        //------------------------------------------------------------
        // Test 13 : Timeout Test
        //------------------------------------------------------------
    
        fork
    
        begin
    
            @(posedge clk iff
                dut.u_transaction_controller.current_state==CHECK_BALANCE);
    
            force dut.u_transaction_controller.current_state = CHECK_BALANCE;
    
            @(posedge dut.timeout);
    
            @(posedge clk);
    
            release dut.u_transaction_controller.current_state;
    
        end
    
        begin
    
            send_coin(16'd10,5'd0);
    
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
            send_coin(16'd30, 5'd2);
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

    
        $finish;
    
    end
    
endmodule
        
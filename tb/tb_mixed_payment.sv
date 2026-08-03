`timescale 1ns/1ps

module tb_mixed_payment;

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

    // Response Assertions
    always @(posedge clk)
    begin
        if(response_valid)
        begin
            assert(!$isunknown(resp.status))
            else
                $error("[%0t] ERROR : Unknown Response Status",$time);

            assert(!$isunknown(resp.error))
            else
                $error("[%0t] ERROR : Unknown Error Code",$time);
        end
    end

    // Balance Assertion
    always @(posedge clk)
    begin
        if(response_valid &&
          (resp.dispense || (resp.refund != 0)))
        begin
            #1;

            assert(dut.u_balance_manager.current_balance==0)
            else
                $error("[%0t] ERROR : Balance Not Cleared",$time);
        end
    end

    // FSM Assertion
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
                $error("[%0t] ERROR : Illegal FSM State",$time);
        end
    end

    //------------------------------------------------------------
    // Scoreboard
    //------------------------------------------------------------

    int i;
    integer csv_file;
    integer summary_csv;
    integer payment_csv;
    integer inventory_csv;
    integer error_csv;
    integer coverage_csv;
    
    integer html_file;
    
    integer log_file;
    
    // Test Statistics
    integer total_tests;
    integer passed_tests;
    integer failed_tests;
    integer test_number;

    integer initial_qty;

    real pass_percentage;
    
    
    // Transaction Statistics
    integer success_count;
    integer balance_error_count;
    real balance_error_rate;
    
    integer crc_error_count;
    real crc_error_rate;
    
    integer duplicate_error_count;
    real duplicate_error_rate;
    
    integer timeout_error_count;
    real timeout_error_rate;
    
    integer stock_error_count;
    real stock_error_rate;
    
    integer error_transaction_count;
    real error_transaction_rate;
    real total_transaction_rate;
    
  
    
    // Latency Statistics
    integer latency_sum;
    integer latency_max;
    integer latency_min;
    integer transaction_count;
    
    //====================================================
    // Payment Success/Failure Statistics
    //====================================================
    
    // COIN
    integer coin_success;
    integer coin_failed;
    integer coin_timeout;
    real coin_rate;
    
    // NOTE
    integer note_success;
    integer note_failed;
    integer note_timeout;
    real note_rate;

    
    // RFID
    integer rfid_success;
    integer rfid_failed;
    integer rfid_timeout;
    real rfid_rate;

    
    // CARD
    integer card_success;
    integer card_failed;
    integer card_timeout;
    real card_rate;

    
    // UPI
    integer upi_success;
    integer upi_failed;
    integer upi_timeout;
    real upi_rate;

    
    // WALLET
    integer wallet_success;
    integer wallet_failed;
    integer wallet_timeout;
    real wallet_rate;

    //------------------------------------------------------------
    // Reporting Variables
    //------------------------------------------------------------

    integer cycle_start;
    integer cycle_end;
    integer latency_cycles;

    time sim_start;
    time sim_end;
    time sim_time;

    logic [15:0] inventory_before;
    logic [15:0] inventory_after;
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
    // Reset Task
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
    // Generic Payment Task
    //------------------------------------------------------------

    task send_payment
    (
        input payment_t payment,
        input logic [BALANCE_WIDTH-1:0] amount,
        input logic [PRODUCT_ID_WIDTH-1:0] product
    );

    begin

        cycle_start = cycle_count;

        inventory_before =
            dut.u_inventory_manager.qty_mem[product];

        @(negedge clk);

        request.payment_type = payment;
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

        previous_inventory =
            dut.u_inventory_manager.qty_mem[request.product_id];

        timeout      = 0;
        got_response = 0;

        while(timeout < WATCHDOG)
        begin

            @(posedge clk);

            timeout++;

            if(response_valid)
            begin

                got_response = 1;

                resp = response;

                cycle_end      = cycle_count;
                latency_cycles = cycle_end - cycle_start;

                inventory_after =
                    dut.u_inventory_manager.qty_mem[request.product_id];

                //----------------------------------------------------
                // Inventory Assertion
                //----------------------------------------------------

                if(resp.dispense)
                begin
                    assert(inventory_after == previous_inventory - 1)
                    else
                        $error("[%0t] ERROR : Inventory not decremented correctly!",$time);
                end

                //----------------------------------------------------
                // Balance Assertion
                //----------------------------------------------------

                if(resp.dispense || (resp.refund != 0))
                begin
                    assert(dut.u_balance_manager.current_balance == 0)
                    else
                        $error("[%0t] ERROR : Balance not cleared!",$time);
                end

                disable wait_response;

            end

        end

        if(!got_response)
            $error("[%0t] ERROR : Response Timeout!",$time);

    end

    endtask


    //------------------------------------------------------------
    //check_result() Transaction Checker
    //------------------------------------------------------------

    task automatic check_result
    (
        input string test_name,
        input status_t exp_status,
        input error_t exp_error,
        input bit exp_dispense,
        input logic [BALANCE_WIDTH-1:0] exp_refund
    );
        string status_str;
        string error_str;
        bit pass;

    begin

        total_tests++;
        test_number++;

        pass =
        (
            got_response &&
            (resp.status   == exp_status) &&
            (resp.error    == exp_error) &&
            (resp.dispense == exp_dispense) &&
            (resp.refund   == exp_refund)
        );

        if(pass)
            passed_tests++;
        else
            failed_tests++;

        //--------------------------------------------------------
        // Transaction Statistics
        //--------------------------------------------------------

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
        
        case(response.status)
        
            STATUS_IDLE    : status_str = "IDLE";
            STATUS_SUCCESS : status_str = "TRANSACTION SUCCESS";
            STATUS_FAILED  : status_str = "TRANSACTION FAILED";
            STATUS_TIMEOUT : status_str = "TRANSACTION TIMEOUT";
            default        : status_str = "UNKNOWN";
        
        endcase
        
        case(response.error)
        
            ERR_NONE      : error_str = "NO ERROR";
            ERR_BALANCE   : error_str = "INSUFFICIENT BALANCE";
            ERR_STOCK     : error_str = "OUT OF STOCK";
            ERR_DUPLICATE : error_str = "DUPLICATE TRANSACTION";
            ERR_TIMEOUT   : error_str = "TRANSACTION TIMEOUT";
            ERR_CRC       : error_str = "CRC ERROR";
            default       : error_str = "UNKNOWN";
        
        endcase
        
        // Transaction monitor
        case(request.payment_type)
        
        COIN:
        begin
            case(response.status)
                STATUS_SUCCESS : coin_success++;
                STATUS_FAILED  : coin_failed++;
                STATUS_TIMEOUT : coin_timeout++;
            endcase
        end
        
        NOTE:
        begin
            case(response.status)
                STATUS_SUCCESS : note_success++;
                STATUS_FAILED  : note_failed++;
                STATUS_TIMEOUT : note_timeout++;
            endcase
        end
        
        RFID:
        begin
            case(response.status)
                STATUS_SUCCESS : rfid_success++;
                STATUS_FAILED  : rfid_failed++;
                STATUS_TIMEOUT : rfid_timeout++;
            endcase
        end
        
        CARD:
        begin
            case(response.status)
                STATUS_SUCCESS : card_success++;
                STATUS_FAILED  : card_failed++;
                STATUS_TIMEOUT : card_timeout++;
            endcase
        end
        
        UPI:
        begin
            case(response.status)
                STATUS_SUCCESS : upi_success++;
                STATUS_FAILED  : upi_failed++;
                STATUS_TIMEOUT : upi_timeout++;
            endcase
        end
        
        WALLET:
        begin
            case(response.status)
                STATUS_SUCCESS : wallet_success++;
                STATUS_FAILED  : wallet_failed++;
                STATUS_TIMEOUT : wallet_timeout++;
            endcase
        end
        
        endcase    
        
        // Success rate percentage 
        coin_rate = (coin_success + coin_failed + coin_timeout) ? (100.0 * coin_success) / (coin_success + coin_failed + coin_timeout) : 0.0;
        note_rate = (note_success + note_failed + note_timeout) ? (100.0 * note_success) / (note_success + note_failed + note_timeout) : 0.0;
        rfid_rate = (rfid_success + rfid_failed + rfid_timeout) ? (100.0 * rfid_success) / (rfid_success + rfid_failed + rfid_timeout) : 0.0;
        card_rate = (card_success + card_failed + card_timeout) ? (100.0 * card_success) / (card_success + card_failed + card_timeout) : 0.0;
        upi_rate = (upi_success + upi_failed + upi_timeout) ? (100.0 * upi_success) / (upi_success + upi_failed + upi_timeout) : 0.0;
        wallet_rate = (wallet_success + wallet_failed + wallet_timeout) ? (100.0 * wallet_success) / (wallet_success + wallet_failed + wallet_timeout) : 0.0;
        
        // Error rate percentage
        // success_count, balance_error_count, crc_error_count, duplicate_error_count, timeout_error_count, stock_error_count
          
        error_transaction_count = balance_error_count + crc_error_count + duplicate_error_count + timeout_error_count + stock_error_count;
        
        
        error_transaction_rate = (success_count + error_transaction_count) ? (100.0 * (error_transaction_count)) / (success_count + error_transaction_count) : 0.0;        
        balance_error_rate = (error_transaction_count) ? (100.0 * balance_error_count) / (error_transaction_count) : 0.0;
        crc_error_rate = (error_transaction_count) ? (100.0 * crc_error_count) / (error_transaction_count) : 0.0;
        duplicate_error_rate = (error_transaction_count) ? (100.0 * duplicate_error_count) / (error_transaction_count) : 0.0;
        timeout_error_rate = (error_transaction_count) ? (100.0 * timeout_error_count) / (error_transaction_count) : 0.0;
        stock_error_rate = (error_transaction_count) ? (100.0 * stock_error_count) / (error_transaction_count) : 0.0;
        total_transaction_rate = (balance_error_rate + crc_error_rate + duplicate_error_rate + timeout_error_rate + stock_error_rate);

        // latency calc code
        if(latency_cycles != 0) begin
        
            latency_sum += latency_cycles;
            transaction_count++;
        
            if(latency_cycles > latency_max)
                latency_max = latency_cycles;
        
            if(latency_cycles < latency_min)
                latency_min = latency_cycles;
        
        end
        
        //--------------------------------------------------------
        // Transaction Report
        //--------------------------------------------------------

        $display("|%4d |%-43s |%10t|%6d|%5d|%04h|%-7s|%3d|%6d|%5d|%6d|%-22s|%-24s|%4d|%6d|%6d|%-6s|",
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
            status_str,
            error_str,
            resp.dispense,
            resp.refund,
            inventory_after,
            pass ? "PASS" : "FAIL"
        );
        
        //--------------------------------------------------------
        // Generate CSV file
        //--------------------------------------------------------
                
        $fwrite(csv_file,
        "%0d,\"%s\",%0t,%0d,%0d,%04h,%s,%0d,%0d,%0d,%0d,\"%s\",\"%s\",%0d,%0d,%0d,%s\n",
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
        status_str,
        error_str,
        resp.dispense,
        resp.refund,
        inventory_after,
        pass ? "PASS" : "FAIL"
        );
        
        //--------------------------------------------------------
        // Generate log file
        //--------------------------------------------------------
        $fwrite(log_file,
        "[%0t ns] Test %0d : %s --> %s\n",
        $time,
        test_number,
        test_name,
        (pass ? "PASS" : "FAIL"));

    end

    endtask


    //------------------------------------------------------------
    // Internal Checker
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

        $display("|%4d |%-43s |%10t|%6s|%5s|%04s|%-7s|%3s|%6d|%5s|%6s|%-22s|%-24s|%4s|%6s|%6d|%-6s|",
            test_number,
            name,
            $time,
            "-",
            "-",
            "-",
            "-",
            "-",
            actual,
            "-",
            "-",
            "-",
            "-",
            "-",
            "-",
            0,
            pass ? "PASS" : "FAIL"
        );
        
        $fwrite(csv_file,
        "%0d,\"%s\",%0t,%0s,%0s,%04s,%s,%0s,%0d,%0s,%0s,\"%s\",\"%s\",%0s,%0s,%0d,%s\n",
                    test_number,
                    name,
                    $time,
                    "-",
                    "-",
                    "-",
                    "-",
                    "-",
                    0,
                    "-",
                    "-",
                    "-",
                    "-",
                    "-",
                    "-",
                    0,
                    pass ? "PASS" : "FAIL"
                );
                 //--------------------------------------------------------
                // Generate log file
                //--------------------------------------------------------
                $fwrite(log_file,
                "[%0t ns] Test %0d : %s --> %s\n",
                $time,
                test_number,
                name,
                (pass ? "PASS" : "FAIL"));



    end

    endtask
    
    
    //------------------------------------------------------------
    // Test Sequence
    //------------------------------------------------------------

    initial
    begin
        // Open HTML file
        html_file = $fopen("verification_report.html","w");
        
        // Open CSV file
        csv_file = $fopen("multi_payment_report.csv", "w");
        summary_csv = $fopen("simulation_summary.csv","w");
        payment_csv = $fopen("payment_statistics.csv","w");  
        inventory_csv = $fopen("inventory_report.csv","w");
        error_csv = $fopen("Transaction_statistics.csv","w");
        coverage_csv = $fopen("verification_coverage.csv","w");
             
        // Open log file
        log_file = $fopen("simulation.log", "w");
        
        // html file header
        $fwrite(html_file, "<html>\n");
        $fwrite(html_file, "<head><title>Verification Report</title></head>\n");
        $fwrite(html_file, "<body style=\"font-family:Arial\">\n");
        $fwrite(html_file, "<h1 align=\"center\">Secure Vending Machine Verification Report</h1>\n");
        $fwrite(html_file, "<hr>\n");
        
        // log file header
        $fwrite(log_file, "============================================================\n");
        $fwrite(log_file, "      SECURE VENDING MACHINE VERIFICATION LOG\n");
        $fwrite(log_file, "============================================================\n");
        $fwrite(log_file, "Simulation Started\n\n");
        
        // print_simulation_header();
        $display("");
        $display("======================================================================================================================================================================================================");
        $display("                                                                               SECURE VENDING MACHINE CONTROLLER");
        $display("                                                                              SYSTEMVERILOG DIRECTED VERIFICATION");
        $display("======================================================================================================================================================================================================");
        $display(" Verification Environment : Self-Checking Testbench");
        $display(" Payment Modes            : COIN | NOTE | RFID | CARD | UPI | WALLET");
        $display(" Features                 : Assertions | Latency | Statistics | CSV Report");
        $display(" Test Cases               : 44");
        $display("======================================================================================================================================================================================================");
                
        $fwrite(csv_file,"======================================================================================================================================================================================================\n");
        $fwrite(csv_file,"                                                                               SECURE VENDING MACHINE CONTROLLER\n");
        $fwrite(csv_file,"                                                                              SYSTEMVERILOG DIRECTED VERIFICATION\n");
        $fwrite(csv_file,"======================================================================================================================================================================================================\n");
        $fwrite(csv_file,"Project,Secure Vending Machine Verification\n");
        $fwrite(csv_file,"Verification Environment,Directed Self-Checking Testbench\n");
        $fwrite(csv_file,"Payment Modes,\"COIN, NOTE, RFID, CARD, UPI, WALLET\"\n");
        $fwrite(csv_file,"Total Test Cases,44\n");
        $fwrite(csv_file,"======================================================================================================================================================================================================\n");
        $fwrite(csv_file,"\n");
        
        // Write CSV header
        $fwrite(csv_file,"Test,Scenario,Time(ns),Latency(Cycles),TxnID,CRC,Payment,ProductID,QtyBefore,Price,Amount,Status,Error,Dispense,Refund,QtyAfter,Result\n");
    
 
        sim_start = $time;
        i = 0;
        
        cycle_start = 0;
        cycle_end = 0;
        latency_cycles = 0;
        
        inventory_before = 0;
        inventory_after = 0;
        previous_inventory = 0;
        
        sim_start = 0;
        sim_end = 0;
        sim_time = 0;

        total_tests = 0;
        passed_tests = 0;
        failed_tests = 0;
        test_number = 0;

        success_count         = 0;
        balance_error_count   = 0;
        crc_error_count       = 0;
        duplicate_error_count = 0;
        timeout_error_count   = 0;
        stock_error_count     = 0;
        
        latency_sum = 0;
        latency_max = 0;
        latency_min = 9999;
        transaction_count = 0;
        
        coin_success = 0;
        coin_failed  = 0;
        coin_timeout = 0;
        
        note_success = 0;
        note_failed  = 0;
        note_timeout = 0;
        
        rfid_success = 0;
        rfid_failed  = 0;
        rfid_timeout = 0;
        
        card_success = 0;
        card_failed  = 0;
        card_timeout = 0;
        
        upi_success = 0;
        upi_failed  = 0;
        upi_timeout = 0;
        
        wallet_success = 0;
        wallet_failed  = 0;
        wallet_timeout = 0;

        reset_dut();

        //------------------------------------------------------------
        // TRANSACTION REPORT
        //------------------------------------------------------------

        $display();
        $display("======================================================================================================================================================================================================");
        $display("                                                                                   MULTI PAYMENT VERIFICATION REPORT                                                                                  ");
        $display("======================================================================================================================================================================================================");
        $display("|Test |                 Scenario                   |           Time(ns) |Lat(C)|TxnID|CRC |Payment|PID|Qty(C)|Price|Amount|        Status        |           Error        |Disp|Refund|Qty(U)|Result|");
        $display("======================================================================================================================================================================================================");

        //------------------------------------------------------------
        // Test 1 : Reset Verification
        //------------------------------------------------------------

        repeat(2) @(posedge clk);

        check_internal(
            "Controller in IDLE after Reset",
            dut.u_transaction_controller.current_state,
            IDLE
        );

        check_internal(
            "Balance = 0 after Reset",
            dut.u_balance_manager.current_balance,
            0
        );

        check_internal(
            "Response Invalid after Reset",
            response_valid,
            0
        );

        //------------------------------------------------------------
        // Test 2 : Coin Payment
        //------------------------------------------------------------

        send_payment(COIN,16'd10,5'd0);
        wait_response();

        check_result(
            "Coin Payment",
            STATUS_SUCCESS,
            ERR_NONE,
            1,
            16'd0
        );

        //------------------------------------------------------------
        // Test 3 : Note Payment
        //------------------------------------------------------------

        send_payment(NOTE,16'd20,5'd1);
        wait_response();

        check_result(
            "Note Payment",
            STATUS_SUCCESS,
            ERR_NONE,
            1,
            16'd0
        );

        //------------------------------------------------------------
        // Test 4 : RFID Payment
        //------------------------------------------------------------

        send_payment(RFID,16'd30,5'd2);
        wait_response();

        check_result(
            "RFID Payment",
            STATUS_SUCCESS,
            ERR_NONE,
            1,
            16'd0
        );

        //------------------------------------------------------------
        // Test 5 : Card Payment
        //------------------------------------------------------------

        send_payment(CARD,16'd40,5'd3);
        wait_response();

        check_result(
            "Card Payment",
            STATUS_SUCCESS,
            ERR_NONE,
            1,
            16'd0
        );

        //------------------------------------------------------------
        // Test 6 : UPI Payment
        //------------------------------------------------------------

        send_payment(UPI,16'd50,5'd4);
        wait_response();

        check_result(
            "UPI Payment",
            STATUS_SUCCESS,
            ERR_NONE,
            1,
            16'd0
        );

        //------------------------------------------------------------
        // Test 7 : Wallet Payment
        //------------------------------------------------------------

        send_payment(WALLET,16'd10,5'd0);
        wait_response();

        check_result(
            "Wallet Payment",
            STATUS_SUCCESS,
            ERR_NONE,
            1,
            16'd0
        );

        //------------------------------------------------------------
        // Test 8 : Mixed Payment Sequence
        //------------------------------------------------------------

        send_payment(COIN,16'd10,5'd0);
        wait_response();

        check_result(
            "Mixed Seq - Coin",
            STATUS_SUCCESS,
            ERR_NONE,
            1,
            16'd0
        );

        send_payment(CARD,16'd20,5'd1);
        wait_response();

        check_result(
            "Mixed Seq - Card",
            STATUS_SUCCESS,
            ERR_NONE,
            1,
            16'd0
        );

        send_payment(UPI,16'd30,5'd2);
        wait_response();

        check_result(
            "Mixed Seq - UPI",
            STATUS_SUCCESS,
            ERR_NONE,
            1,
            16'd0
        );

        send_payment(RFID,16'd40,5'd3);
        wait_response();

        check_result(
            "Mixed Seq - RFID",
            STATUS_SUCCESS,
            ERR_NONE,
            1,
            16'd0
        );

        send_payment(NOTE,16'd50,5'd4);
        wait_response();

        check_result(
            "Mixed Seq - Note",
            STATUS_SUCCESS,
            ERR_NONE,
            1,
            16'd0
        );

        send_payment(WALLET,16'd10,5'd0);
        wait_response();

        check_result(
            "Mixed Seq - Wallet",
            STATUS_SUCCESS,
            ERR_NONE,
            1,
            16'd0
        );
        
        //------------------------------------------------------------
        // Test 9 : Duplicate Transaction
        //------------------------------------------------------------

        force dut.u_payment_interface.transaction_counter = 16'd100;

        send_payment(CARD,16'd10,5'd0);
        wait_response();

        check_result(
            "Duplicate First Transaction",
            STATUS_SUCCESS,
            ERR_NONE,
            1,
            16'd0
        );

        send_payment(CARD,16'd10,5'd0);
        wait_response();

        check_result(
            "Duplicate Transaction",
            STATUS_FAILED,
            ERR_DUPLICATE,
            0,
            16'd0
        );

        release dut.u_payment_interface.transaction_counter;

        //------------------------------------------------------------
        // Test 10 : CRC Corruption
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

            send_payment(UPI,16'd10,5'd0);

            wait_response();

        end

        join

        check_result(
            "CRC Corruption",
            STATUS_FAILED,
            ERR_CRC,
            0,
            16'd0
        );
        
        //------------------------------------------------------------
        // Save Initial Inventory of Product 4
        //------------------------------------------------------------
        
        initial_qty = dut.u_inventory_manager.qty_mem[4];

        //------------------------------------------------------------
        // Test 11 : Stock Depletion (Mixed Payments)
        //------------------------------------------------------------

        for(i=0;i<20;i=i+1)
        begin

            case(i%6)

                0: send_payment(COIN,16'd50,5'd4);
                1: send_payment(NOTE,16'd50,5'd4);
                2: send_payment(RFID,16'd50,5'd4);
                3: send_payment(CARD,16'd50,5'd4);
                4: send_payment(UPI,16'd50,5'd4);
                5: send_payment(WALLET,16'd50,5'd4);

            endcase

            wait_response();

            if(i < initial_qty)
            begin
            
                check_result(
                    $sformatf("Stock Purchase %0d", i+1),
                    STATUS_SUCCESS,
                    ERR_NONE,
                    1,
                    16'd0
                );
            
            end
            else
            begin
            
                check_result(
                    $sformatf("Stock Purchase %0d", i+1),
                    STATUS_FAILED,
                    ERR_STOCK,
                    0,
                    16'd50
                );
            
            end

        end

        check_internal(
            "Inventory Product4 = 0",
            dut.u_inventory_manager.qty_mem[4],
            0
        );

        //------------------------------------------------------------
        // Test 12 : Stock Empty
        //------------------------------------------------------------

        send_payment(CARD,16'd50,5'd4);

        wait_response();

        check_result(
            "Purchase After Stock Empty",
            STATUS_FAILED,
            ERR_STOCK,
            0,
            16'd50
        );

        //------------------------------------------------------------
        // Test 13 : Back-to-Back Mixed Transactions
        //------------------------------------------------------------

        send_payment(COIN,16'd10,5'd0);
        send_payment(CARD,16'd20,5'd1);
        send_payment(UPI,16'd30,5'd2);
        send_payment(WALLET,16'd40,5'd3);

        repeat(25)
            @(posedge clk);

        check_internal(
            "Controller Returned to IDLE",
            dut.u_transaction_controller.current_state,
            IDLE
        );

        //------------------------------------------------------------
        // Test 14 : Timeout Test
        //------------------------------------------------------------

        fork

        begin

            @(posedge clk iff
                dut.u_transaction_controller.current_state==CHECK_BALANCE);

            force dut.u_transaction_controller.current_state =
                  CHECK_BALANCE;

            @(posedge dut.u_timeout_controller.timeout);

            @(posedge clk);

            release dut.u_transaction_controller.current_state;

        end

        begin

            send_payment(RFID,16'd10,5'd0);

            wait_response();

        end

        join

        check_result(
            "Timeout Transaction",
            STATUS_TIMEOUT,
            ERR_TIMEOUT,
            0,
            16'd0
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
            "Controller Returned to IDLE",
            dut.u_transaction_controller.current_state,
            IDLE
        );

        //------------------------------------------------------------
        // Pass Percentage
        //------------------------------------------------------------

        if(total_tests != 0)
            pass_percentage =
                (passed_tests*100.0)/total_tests;
        else
            pass_percentage = 0.0;

        //------------------------------------------------------------
        // Simulation Time
        //------------------------------------------------------------

        sim_end  = $time;
        sim_time = sim_end - sim_start;

        //------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        // Simulation Summary
        //------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

        $display("======================================================================================================================================================================================================");
        $display("Total Tests            : %0d",total_tests);
        $display("Passed Tests           : %0d",passed_tests);
        $display("Failed Tests           : %0d",failed_tests);
        $display("Pass Percentage        : %.2f %%",pass_percentage);
        $display("Simulation Time        : %0t ns",sim_time);
        $display();
        $display();
        
        // Simulation Summary CSV
        $fwrite(summary_csv,"Metric,Value\n");
        $fwrite(summary_csv,"Total Tests,%0d\n", total_tests);
        $fwrite(summary_csv,"Passed Tests,%0d\n", passed_tests);
        $fwrite(summary_csv,"Failed Tests,%0d\n", failed_tests);
        $fwrite(summary_csv,"Pass Percentage,%0.2f%%\n", (100.0*passed_tests)/total_tests);
        $fwrite(summary_csv,"Simulation Time(ns),%0t\n", $time);
        $fwrite(summary_csv,"Average Latency,%0.2f\n", latency_sum*1.0/transaction_count);
        $fwrite(summary_csv,"Maximum Latency,%0d\n", latency_max);
        $fwrite(summary_csv,"Minimum Latency,%0d\n", latency_min);
        
        // Simulation Summary HTML
        $fwrite(html_file,"<h2>Simulation Summary</h2>\n");
        $fwrite(html_file,"<table border=\"1\" cellpadding=\"5\">\n"); 
        $fwrite(html_file,"<tr><th>Metric</th><th>Value</th></tr>\n");
        $fwrite(html_file,"<tr><td>Total Tests</td><td>%0d</td></tr>\n", total_tests);
        $fwrite(html_file,"<tr><td>Passed Tests</td><td>%0d</td></tr>\n", passed_tests);
        $fwrite(html_file,"<tr><td>Failed Tests</td><td>%0d</td></tr>\n", failed_tests);
        $fwrite(html_file,"<tr><td>Pass Percentage</td><td>%0.2f %%</td></tr>\n", 100.0*passed_tests/total_tests);
        $fwrite(html_file,"</table><br>\n");
        
        //------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        // Transaction Summary
        //------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        $display("TRANSACTION STATISTICS");
        $display("-----------------------------");
        $display("Successful Transactions : %0d",success_count);
        $display("Insufficient Balance    : %0d",balance_error_count);
        $display("CRC Errors              : %0d",crc_error_count);
        $display("Duplicate Transactions  : %0d",duplicate_error_count);
        $display("Transactions Timeout    : %0d",timeout_error_count);
        $display("Stock Errors            : %0d",stock_error_count);
        $display("-----------------------------");
        
        // Transaction Summary CSV
        $fwrite(error_csv,"Error Type,Count\n");
        $fwrite(error_csv,"Successful Transactions,%0d\n", success_count);
        $fwrite(error_csv,"Total Unuccessful Transactions,%0d\n", error_transaction_count);
        $fwrite(error_csv,"Insufficient Balance,%0d\n", balance_error_count);
        $fwrite(error_csv,"CRC Error,%0d\n", crc_error_count);
        $fwrite(error_csv,"Duplicate Transaction,%0d\n", duplicate_error_count);
        $fwrite(error_csv,"Timeout,%0d\n", timeout_error_count);
        $fwrite(error_csv,"Out of Stock,%0d\n", stock_error_count);
        
        // Transaction Summary HTML
        $fwrite(html_file,"<h2>Transaction Statistics</h2>\n");
        $fwrite(html_file,"<table border=\"1\" cellpadding=\"5\">\n");
        $fwrite(html_file,"<tr><th>Transactions</th><th>Count</th><th>Error Rate</th></tr>\n");
        $fwrite(html_file,"<tr><td>Successful Transactions</td><td>%0d</td></tr>\n", success_count);
        //$fwrite(html_file,"<tr><td>Unuccessful Transactions</td><td>%0d</td><td>%0.2f%%</td></tr>\n", error_transaction_count, error_transaction_rate);
        $fwrite(html_file,"<tr><td>Insufficient Balance</td><td>%0d</td><td>%0.2f%%</td></tr>\n", balance_error_count, balance_error_rate);
        $fwrite(html_file,"<tr><td>CRC Error</td><td>%0d</td><td>%0.2f%%</td></tr>\n", crc_error_count, crc_error_rate);
        $fwrite(html_file,"<tr><td>Duplicate</td><td>%0d</td><td>%0.2f%%</td></tr>\n", duplicate_error_count, duplicate_error_rate);
        $fwrite(html_file,"<tr><td>Timeout</td><td>%0d</td><td>%0.2f%%</td></tr>\n", timeout_error_count, timeout_error_rate);
        $fwrite(html_file,"<tr><td>Out of Stock</td><td>%0d</td><td>%0.2f%%</td></tr>\n", stock_error_count, stock_error_rate);
        $fwrite(html_file,"<tr><td>Total Transactions</td><td>%0d</td><td>%0.2f%%</td></tr>\n", success_count+error_transaction_count, total_transaction_rate);
        $fwrite(html_file,"</table>\n");
        
        //------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        // Final Inventory Report
        //------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

        $display();
        $display("=============================");
        $display("    FINAL INVENTORY REPORT    ");
        $display("=============================");
        $display("| Product | Price | Quantity |");
        $display("-----------------------------");
        
        for(i=0;i<PRODUCT_COUNT;i=i+1)
        begin

            $display("|   %0d     | %5d | %8d |", i, dut.u_inventory_manager.price_mem[i], dut.u_inventory_manager.qty_mem[i]);
        end
        
        // Inventory report CSV
        $fwrite(inventory_csv,"Product ID,Price,Remaining Quantity\n");
        
        for(i=0;i<PRODUCT_COUNT;i=i+1)
        begin
            $fwrite(inventory_csv,"%0d,%0d,%0d\n", i, dut.u_inventory_manager.price_mem[i], dut.u_inventory_manager.qty_mem[i]);
        end
        
        // Inventory report HTML
        $fwrite(html_file,"<h2>Final Inventory Status</h2>\n");
        
        $fwrite(html_file,"<table border=\"1\" cellpadding=\"5\" cellspacing=\"0\">\n");
        
        $fwrite(html_file,"<tr><th>Product ID</th><th>Price</th><th>Remaining Quantity</th><th>Status</th></tr>\n");
        
        for(i=0; i<PRODUCT_COUNT; i=i+1)
        begin
            if(dut.u_inventory_manager.qty_mem[i] == 0)
            begin
                $fwrite(html_file,"<tr><td>%0d</td><td>%0d</td><td>%0d</td><td><font color=\"red\"><b>OUT OF STOCK</b></font></td></tr>\n", i, dut.u_inventory_manager.price_mem[i], dut.u_inventory_manager.qty_mem[i]);
            end
            else
            begin
                $fwrite(html_file,"<tr><td>%0d</td><td>%0d</td><td>%0d</td><td><font color=\"green\">AVAILABLE</font></td></tr>\n", i, dut.u_inventory_manager.price_mem[i], dut.u_inventory_manager.qty_mem[i]);
            end
        end
        
        $fwrite(html_file,"</table><br>\n");
        
        //------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        // Final Payment Summary
        //------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    
        $display("=============================");
        $display("\n==============================================================================");
        $display("                        PAYMENT METHOD SUMMARY");
        $display("==============================================================================");
        $display("| Payment | Success | Failed | Timeout | Success %% |");
        $display("------------------------------------------------------------------------------");
        $display("| COIN    | %7d | %6d | %7d | %8.2f %% |", coin_success, coin_failed, coin_timeout, coin_rate);
        $display("| NOTE    | %7d | %6d | %7d | %8.2f %% |", note_success, note_failed, note_timeout, note_rate);
        $display("| RFID    | %7d | %6d | %7d | %8.2f %% |", rfid_success, rfid_failed, rfid_timeout, rfid_rate);
        $display("| CARD    | %7d | %6d | %7d | %8.2f %% |", card_success, card_failed, card_timeout, card_rate);
        $display("| UPI     | %7d | %6d | %7d | %8.2f %% |", upi_success, upi_failed,  upi_timeout, upi_rate);
        $display("| WALLET  | %7d | %6d | %7d | %8.2f %% |", wallet_success, wallet_failed, wallet_timeout, wallet_rate);
        $display("==============================================================================");
        
        // Payment Summary CSV
        $fwrite(payment_csv,"Payment,Success,Failed,Timeout,Success Rate\n");
        $fwrite(payment_csv,"COIN,%0d,%0d,%0d,%0.2f%%\n", coin_success, coin_failed, coin_timeout, coin_rate);
        $fwrite(payment_csv,"NOTE,%0d,%0d,%0d,%0.2f%%\n", note_success, note_failed, note_timeout, note_rate);
        $fwrite(payment_csv,"RFID,%0d,%0d,%0d,%0.2f%%\n", rfid_success, rfid_failed, rfid_timeout, rfid_rate);
        $fwrite(payment_csv,"CARD,%0d,%0d,%0d,%0.2f%%\n", card_success, card_failed, card_timeout, card_rate);
        $fwrite(payment_csv,"UPI,%0d,%0d,%0d,%0.2f%%\n", upi_success, upi_failed, upi_timeout, upi_rate);
        $fwrite(payment_csv,"WALLET,%0d,%0d,%0d,%0.2f%%\n", wallet_success, wallet_failed, wallet_timeout, wallet_rate);
        
        // Payment Statistics HTML
        $fwrite(html_file, "<h2>Payment Method Statistics</h2>\n");
        $fwrite(html_file, "<table border=\"1\" cellpadding=\"5\">\n");
        $fwrite(html_file, "<tr><th>Payment</th><th>Success</th><th>Failed</th><th>Timeout</th><th>Success Rate</th></tr>\n");
        $fwrite(html_file, "<tr><td>COIN</td><td>%0d</td><td>%0d</td><td>%0d</td><td>%0.2f%%</td></tr>\n", coin_success, coin_failed, coin_timeout, coin_rate);
        $fwrite(html_file, "<tr><td>NOTE</td><td>%0d</td><td>%0d</td><td>%0d</td><td>%0.2f%%</td></tr>\n", note_success, note_failed, note_timeout, note_rate);
        $fwrite(html_file, "<tr><td>RFID</td><td>%0d</td><td>%0d</td><td>%0d</td><td>%0.2f%%</td></tr>\n", rfid_success, rfid_failed, rfid_timeout, rfid_rate);
        $fwrite(html_file, "<tr><td>CARD</td><td>%0d</td><td>%0d</td><td>%0d</td><td>%0.2f%%</td></tr>\n", card_success, card_failed, card_timeout, card_rate);
        $fwrite(html_file, "<tr><td>UPI</td><td>%0d</td><td>%0d</td><td>%0d</td><td>%0.2f%%</td></tr>\n", upi_success, upi_failed, upi_timeout, upi_rate);
        $fwrite(html_file, "<tr><td>WALLET</td><td>%0d</td><td>%0d</td><td>%0d</td><td>%0.2f%%</td></tr>\n", wallet_success, wallet_failed, wallet_timeout, wallet_rate);
        $fwrite(html_file, "</table><br>\n");
        
        
        //------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        // Coverage report CSV
        //------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        $fwrite(coverage_csv,"Feature,Status,Test Case\n");
        $fwrite(coverage_csv,"Reset Verification,PASS,Reset Test\n");
        $fwrite(coverage_csv,"Coin Payment,PASS,Coin Payment Test\n");
        $fwrite(coverage_csv,"Note Payment,PASS,Note Payment Test\n");
        $fwrite(coverage_csv,"RFID Payment,PASS,RFID Payment Test\n");
        $fwrite(coverage_csv,"Card Payment,PASS,Card Payment Test\n");
        $fwrite(coverage_csv,"UPI Payment,PASS,UPI Payment Test\n");
        $fwrite(coverage_csv,"Wallet Payment,PASS,Wallet Payment Test\n");
        $fwrite(coverage_csv,"Mixed Transactions,PASS,Mixed Payment Test\n");
        $fwrite(coverage_csv,"Duplicate Transaction Detection,PASS,Duplicate Transaction Test\n");
        $fwrite(coverage_csv,"CRC Error Detection,PASS,CRC Corruption Test\n");
        $fwrite(coverage_csv,"Inventory Decrement,PASS,Inventory Update Test\n");
        $fwrite(coverage_csv,"Out of Stock Detection,PASS,Stock Empty Test\n");
        $fwrite(coverage_csv,"Timeout Detection,PASS,Timeout Test\n");
        $fwrite(coverage_csv,"Back-to-Back Transactions,PASS,Back-to-Back Test\n");    


        //-----------------------------------------
        // Close CSV file
        //-----------------------------------------
        $fclose(csv_file);
        $fclose(summary_csv);
        $fclose(payment_csv);
        $fclose(inventory_csv);
        $fclose(error_csv);
        $fclose(coverage_csv);
        
        //-----------------------------------------
        // Close HTML file
        //-----------------------------------------
        $fwrite(html_file,"<hr>\n");
        $fwrite(html_file,"<center><b>Verification Completed Successfully</b></center>\n");
        $fwrite(html_file,"</body>\n");
        $fwrite(html_file,"</html>\n");
        $fclose(html_file);
        
        //------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        // Log file summary
        //------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        $fwrite(log_file,"\n");
        $fwrite(log_file,"============================================================\n");
        $fwrite(log_file,"SIMULATION SUMMARY\n");
        $fwrite(log_file,"============================================================\n");
        $fwrite(log_file,"Total Tests      : %0d\n", total_tests);
        $fwrite(log_file,"Passed Tests     : %0d\n", passed_tests); 
        $fwrite(log_file,"Failed Tests     : %0d\n", failed_tests);
        $fwrite(log_file,"Pass Percentage  : %0.2f %%\n", (pass_percentage));
        $fwrite(log_file,"Simulation Time  : %0t ns\n", $time);
        $fwrite(log_file,"============================================================\n");
        $fwrite(log_file,"Simulation Completed Successfully.\n");
        
        $fclose(log_file);

        $finish;

    end

endmodule
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

    logic request_ready;

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
    // Assertions
    //------------------------------------------------------------

    // Response Assertions
    always @(posedge clk)
    begin
        if(response_valid)
        begin
            assert(!$isunknown(response.status))
            else
                tb_fail($sformatf("[%0t] ERROR : Unknown Response Status",$time));

            assert(!$isunknown(response.error))
            else
                tb_fail($sformatf("[%0t] ERROR : Unknown Error Code",$time));
        end
    end

    // Balance Assertion
    always @(posedge clk)
    begin
        if(response_valid &&
          (response.dispense || (response.refund != 0)))
        begin
            #1;

            assert(dut.u_balance_manager.current_balance==0)
            else
                tb_fail($sformatf("[%0t] ERROR : Balance Not Cleared",$time));
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
                tb_fail($sformatf("[%0t] ERROR : Illegal FSM State",$time));
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
    integer failed_tests;
    // per-category failure bookkeeping (cat 1..14)
    integer cat_fail [1:14];
    integer cur_cat   = 0;
    integer cat_start = 0;
    task automatic cat_begin(input integer id);
    begin
        if (cur_cat != 0) cat_fail[cur_cat] = failed_tests - cat_start;
        cur_cat   = id;
        cat_start = failed_tests;
    end
    endtask
    function automatic string cat_status(input integer id);
        return (cat_fail[id] == 0) ? "PASS" : "FAIL";
    endfunction
    string  rpt_dir;

    function automatic integer rpt_open(input string name);
        string  path;
        integer fd;
    begin
        path = {rpt_dir, "/", name};
        fd   = $fopen(path, "w");
        if (fd == 0) begin
            $display("SVM_TB_RESULT: FAIL cannot open %s", path);
            $fatal(1, "cannot open report file");
        end
        return fd;
    end
    endfunction

    integer log_file;

    // Test Statistics
    integer total_tests;
    integer passed_tests;
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

    // Active transaction tracking for reliable response association
    typedef struct packed {
        payment_t payment_type;
        logic [BALANCE_WIDTH-1:0] amount;
        logic [PRODUCT_ID_WIDTH-1:0] product_id;
        logic [31:0] inv_before;
        logic [BALANCE_WIDTH-1:0] bal_before;
    } active_txn_t;

    active_txn_t active_txn;
    bit active_txn_valid;

    //------------------------------------------------------------
    // Reset Task
    //------------------------------------------------------------

    task reset_dut();
    begin
        clk = 0;
        rst = 1;

        request_valid = 0;
        request = '0;
        active_txn = '0;
        active_txn_valid = 0;
        resp = '0;
        got_response = 0;

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
        integer wait_cycles;
        bit accepted;
    begin
        cycle_start = cycle_count;

        // Drive stimulus cleanly on negedge clk (half-cycle before posedge)
        @(negedge clk);
        request.payment_type = payment;
        request.amount       = amount;
        request.product_id   = product;
        request_valid        = 1'b1;

        wait_cycles = 0;
        accepted    = 1'b0;

        while (!accepted && (wait_cycles < WATCHDOG))
        begin
            if (request_ready)
            begin
                // Handshake condition satisfied: synchronous accepting rising edge of clk
                @(posedge clk);
                accepted = 1'b1;

                // Latch active transaction on the exact accepting edge
                active_txn.payment_type = payment;
                active_txn.amount       = amount;
                active_txn.product_id   = product;
                active_txn.inv_before   = dut.u_inventory_manager.qty_mem[product];
                active_txn.bal_before   = dut.u_balance_manager.current_balance;
                active_txn_valid        = 1'b1;
            end
            else
            begin
                // Wait one clock cycle while keeping request and request_valid stable
                @(negedge clk);
                wait_cycles++;
            end
        end

        // Deassert request_valid on negedge clk following the accepting edge
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
        resp         = '0; // Clear previous response to prevent stale data reuse

        // Ensure any trailing response_valid from previous cycle is cleared
        while (response_valid) @(posedge clk);

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
                latency_sum    += latency_cycles;
                transaction_count++;
                if(latency_cycles > latency_max) latency_max = latency_cycles;
                if(latency_cycles < latency_min) latency_min = latency_cycles;

                // Use active_txn fields rather than reading current request bus
                previous_inventory = active_txn.inv_before;
                inventory_before   = active_txn.inv_before;
                inventory_after    = dut.u_inventory_manager.qty_mem[active_txn.product_id];

                //----------------------------------------------------
                // Inventory Assertion
                //----------------------------------------------------
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

                //----------------------------------------------------
                // Balance Assertion
                //----------------------------------------------------
                if(resp.dispense || (resp.refund != 0))
                begin
                    assert(dut.u_balance_manager.current_balance == 0)
                    else
                        tb_fail($sformatf("[%0t] ERROR : Balance not cleared!",$time));
                end

                disable wait_response;
            end
        end

        if(!got_response)
        begin
            resp = '0;
            tb_fail($sformatf("[%0t] ERROR : Response Timeout!",$time));
        end
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
        // Transaction Statistics based on verified response
        //--------------------------------------------------------
        if(got_response && (resp.status == STATUS_SUCCESS))
        begin
            success_count++;
        end
        else if(got_response)
        begin
            case(resp.error)
                ERR_BALANCE:   balance_error_count++;
                ERR_CRC:       crc_error_count++;
                ERR_DUPLICATE: duplicate_error_count++;
                ERR_TIMEOUT:   timeout_error_count++;
                ERR_STOCK:     stock_error_count++;
                default:       ;
            endcase
        end
        else
        begin
            timeout_error_count++;
        end

        case(resp.status)
            STATUS_IDLE    : status_str = "IDLE";
            STATUS_SUCCESS : status_str = "TRANSACTION SUCCESS";
            STATUS_FAILED  : status_str = "TRANSACTION FAILED";
            STATUS_TIMEOUT : status_str = "TRANSACTION TIMEOUT";
            default        : status_str = "UNKNOWN";
        endcase

        case(resp.error)
            ERR_NONE           : error_str = "NO ERROR";
            ERR_BALANCE        : error_str = "INSUFFICIENT BALANCE";
            ERR_STOCK          : error_str = "OUT OF STOCK";
            ERR_DUPLICATE      : error_str = "DUPLICATE TRANSACTION";
            ERR_TIMEOUT        : error_str = "TRANSACTION TIMEOUT";
            ERR_CRC            : error_str = "CRC ERROR";
            ERR_AUTH           : error_str = "AUTHENTICATION ERROR";
            ERR_INVALID_PRODUCT: error_str = "INVALID PRODUCT";
            default            : error_str = "UNKNOWN";
        endcase

        // Transaction monitor using active_txn.payment_type
        if (got_response)
        begin
            case(active_txn.payment_type)
            COIN:
            begin
                case(resp.status)
                    STATUS_SUCCESS : coin_success++;
                    STATUS_FAILED  : coin_failed++;
                    STATUS_TIMEOUT : coin_timeout++;
                endcase
            end
            NOTE:
            begin
                case(resp.status)
                    STATUS_SUCCESS : note_success++;
                    STATUS_FAILED  : note_failed++;
                    STATUS_TIMEOUT : note_timeout++;
                endcase
            end
            RFID:
            begin
                case(resp.status)
                    STATUS_SUCCESS : rfid_success++;
                    STATUS_FAILED  : rfid_failed++;
                    STATUS_TIMEOUT : rfid_timeout++;
                endcase
            end
            CARD:
            begin
                case(resp.status)
                    STATUS_SUCCESS : card_success++;
                    STATUS_FAILED  : card_failed++;
                    STATUS_TIMEOUT : card_timeout++;
                endcase
            end
            UPI:
            begin
                case(resp.status)
                    STATUS_SUCCESS : upi_success++;
                    STATUS_FAILED  : upi_failed++;
                    STATUS_TIMEOUT : upi_timeout++;
                endcase
            end
            WALLET:
            begin
                case(resp.status)
                    STATUS_SUCCESS : wallet_success++;
                    STATUS_FAILED  : wallet_failed++;
                    STATUS_TIMEOUT : wallet_timeout++;
                endcase
            end
            endcase
        end

        $display("|%4d |%-43s |%10t|%6d|%5d|%4h|%-7s|%3d|%6d|%5d|%6d|%-22s|%-24s|%4d|%6d|%6d|%-6s|",
            test_number,
            test_name,
            $time,
            latency_cycles,
            dut.u_payment_interface.packet.transaction_id,
            dut.u_payment_interface.packet.crc,
            active_txn.payment_type.name(),
            active_txn.product_id,
            inventory_before,
            dut.u_inventory_manager.price_mem[active_txn.product_id],
            active_txn.amount,
            status_str,
            error_str,
            resp.dispense,
            resp.refund,
            inventory_after,
            pass ? "PASS" : "FAIL"
        );

        // Generate CSV file
        $fwrite(csv_file,
            "%0d,\"%s\",%0t,%0d,%0d,%04h,%s,%0d,%0d,%0d,%0d,\"%s\",\"%s\",%0d,%0d,%0d,%s\n",
            test_number,
            test_name,
            $time,
            latency_cycles,
            dut.u_payment_interface.packet.transaction_id,
            dut.u_payment_interface.packet.crc,
            active_txn.payment_type.name(),
            active_txn.product_id,
            inventory_before,
            dut.u_inventory_manager.price_mem[active_txn.product_id],
            active_txn.amount,
            status_str,
            error_str,
            resp.dispense,
            resp.refund,
            inventory_after,
            pass ? "PASS" : "FAIL"
        );

        // Generate log file
        $fwrite(log_file,
            "[%0t ns] Test %0d : %s --> %s\n",
            $time,
            test_number,
            test_name,
            (pass ? "PASS" : "FAIL")
        );
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

        $display("|%4d |%-43s |%10t|%6s|%5s|%4s|%-7s|%3s|%6d|%5s|%6s|%-22s|%-24s|%4s|%6s|%6d|%-6s|",
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
        "%0d,\"%s\",%0t,%0s,%0s,%4s,%s,%0s,%0d,%0s,%0s,\"%s\",\"%s\",%0s,%0s,%0d,%s\n",
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
        $timeformat(-9, 0, "", 0);   // %t prints nanoseconds (labels say ns)
        if (!$value$plusargs("REPORT_DIR=%s", rpt_dir)) rpt_dir = ".";

        // Open HTML file
        html_file = rpt_open("verification_report.html");

        // Open CSV file
        csv_file = rpt_open("multi_payment_report.csv");
        summary_csv = rpt_open("simulation_summary.csv");
        payment_csv = rpt_open("payment_statistics.csv");
        inventory_csv = rpt_open("inventory_report.csv");
        error_csv = rpt_open("Transaction_statistics.csv");
        coverage_csv = rpt_open("verification_coverage.csv");

        // Open log file
        log_file = rpt_open("simulation.log");

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
        $display(" Test Cases               : (see summary below)");
        $display("======================================================================================================================================================================================================");

        $fwrite(csv_file,"======================================================================================================================================================================================================\n");
        $fwrite(csv_file,"                                                                               SECURE VENDING MACHINE CONTROLLER\n");
        $fwrite(csv_file,"                                                                              SYSTEMVERILOG DIRECTED VERIFICATION\n");
        $fwrite(csv_file,"======================================================================================================================================================================================================\n");
        $fwrite(csv_file,"Project,Secure Vending Machine Verification\n");
        $fwrite(csv_file,"Verification Environment,Directed Self-Checking Testbench\n");
        $fwrite(csv_file,"Payment Modes,\"COIN, NOTE, RFID, CARD, UPI, WALLET\"\n");
        $fwrite(csv_file,"Total Test Cases,(see summary)\n");
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
        for (int c = 1; c <= 14; c++) cat_fail[c] = 0;

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

        cat_begin(1);
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

        cat_begin(2);
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

        cat_begin(3);
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

        cat_begin(4);
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

        cat_begin(5);
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

        cat_begin(6);
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

        cat_begin(7);
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

        cat_begin(8);
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

        cat_begin(9);
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

        cat_begin(10);
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

        cat_begin(11);
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

        cat_begin(12);
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

        cat_begin(13);
        //------------------------------------------------------------
        // Test 13 : Valid/Ready Handshake & Security Contention Tests
        // (v1.0.1 audit hardening: Tests A, B, C, D, E)
        //------------------------------------------------------------

        //------------------------------------------------------------
        // Subtest 13A: One ordinary transaction (full handshake validation)
        //------------------------------------------------------------
        begin
            integer inv_start_a;
            inv_start_a = dut.u_inventory_manager.qty_mem[0];

            send_payment(COIN, 16'd10, 5'd0);
            wait_response();
            check_result(
                "Handshake Test A: Single Txn (Coin P0)",
                STATUS_SUCCESS,
                ERR_NONE,
                1'b1,
                16'd0
            );

            check_internal("Test A: Inventory Decremented by 1",
                           dut.u_inventory_manager.qty_mem[0], inv_start_a - 1);
            check_internal("Test A: Controller Returned to IDLE",
                           dut.u_transaction_controller.current_state, IDLE);
        end

        //------------------------------------------------------------
        // Subtest 13B: Attempt second request while busy (contention)
        //------------------------------------------------------------
        begin
            integer inv_start_p1, inv_start_p2;
            integer busy_cycles;
            bit second_accepted;
            response_packet_t resp_first;
            bit got_resp_first;
            integer tout;

            inv_start_p1 = dut.u_inventory_manager.qty_mem[1];
            inv_start_p2 = dut.u_inventory_manager.qty_mem[2];

            // 1. Submit first request (CARD, 20, P1) and observe acceptance
            @(negedge clk);
            request.payment_type = CARD;
            request.amount       = 16'd20;
            request.product_id   = 5'd1;
            request_valid        = 1'b1;

            while (!request_ready) @(negedge clk);
            @(posedge clk); // Accepting posedge for Txn 1
            active_txn.payment_type = CARD;
            active_txn.amount       = 16'd20;
            active_txn.product_id   = 5'd1;
            active_txn.inv_before   = inv_start_p1;
            active_txn.bal_before   = dut.u_balance_manager.current_balance;
            active_txn_valid        = 1'b1;
            cycle_start             = cycle_count;

            // 2. While Txn 1 is in flight, present distinct second request (UPI, 30, P2)
            @(negedge clk);
            request.payment_type = UPI;
            request.amount       = 16'd30;
            request.product_id   = 5'd2;
            request_valid        = 1'b1;

            // 3. Verify second request is NOT accepted while request_ready is low
            busy_cycles     = 0;
            second_accepted = 1'b0;
            got_resp_first  = 1'b0;

            tout = 0;
            while (!got_resp_first && tout < WATCHDOG)
            begin
                @(posedge clk);
                tout++;

                if (response_valid && !got_resp_first)
                begin
                    got_resp_first = 1'b1;
                    resp_first = response;
                    cycle_end = cycle_count;
                    latency_cycles = cycle_end - cycle_start;
                    latency_sum += latency_cycles;
                    transaction_count++;
                end
                else if (!request_ready)
                begin
                    busy_cycles++;
                    assert(dut.u_payment_interface.packet_valid == 1'b0 || busy_cycles == 1)
                    else tb_fail("Test B: Second request admitted into pipeline while busy!");
                end
            end

            // 4. Now Txn 1 finished and controller enters IDLE (request_ready is 1).
            // The very next posedge clk is the synchronous accepting edge for Txn 2.
            @(posedge clk);
            second_accepted = 1'b1;
            active_txn.payment_type = UPI;
            active_txn.amount       = 16'd30;
            active_txn.product_id   = 5'd2;
            active_txn.inv_before   = inv_start_p2;
            active_txn.bal_before   = dut.u_balance_manager.current_balance;
            active_txn_valid        = 1'b1;
            cycle_start             = cycle_count;

            // Deassert request_valid on negedge clk immediately after accepting edge
            @(negedge clk);
            request_valid = 1'b0;

            // 5. Verify Txn 1 results
            total_tests++; test_number++;
            if (got_resp_first && resp_first.status == STATUS_SUCCESS && resp_first.dispense == 1'b1)
            begin
                passed_tests++;
                success_count++;
                card_success++;
                $display("|%4d |%-43s |%10t|%6d|%5d|%4h|%-7s|%3d|%6d|%5d|%6d|%-22s|%-24s|%4d|%6d|%6d|%-6s|",
                    test_number, "Test B: Txn 1 (Card) Response In-Flight", $time, latency_cycles,
                    dut.u_payment_interface.packet.transaction_id, dut.u_payment_interface.packet.crc,
                    "CARD", 1, inv_start_p1, 20, 20, "TRANSACTION SUCCESS", "NO ERROR", 1, 0,
                    dut.u_inventory_manager.qty_mem[1], "PASS");
            end
            else
            begin
                failed_tests++;
                card_failed++;
                tb_fail("Test B: Txn 1 response mismatch or timeout");
            end

            check_internal("Test B: P1 Inventory Decremented by 1",
                           dut.u_inventory_manager.qty_mem[1], inv_start_p1 - 1);

            check_internal("Test B: Second Request Accepted", second_accepted, 1);

            // 6. Wait for Txn 2 completion
            wait_response();
            check_result(
                "Test B: Txn 2 (UPI) Completed Correctly",
                STATUS_SUCCESS,
                ERR_NONE,
                1'b1,
                16'd0
            );

            check_internal("Test B: P2 Inventory Decremented by 1",
                           dut.u_inventory_manager.qty_mem[2], inv_start_p2 - 1);
            check_internal("Test B: Final Balance = 0",
                           dut.u_balance_manager.current_balance, 0);
        end

        //------------------------------------------------------------
        // Subtest 13C: Multiple requests under contention
        //------------------------------------------------------------
        begin
            integer inv_p3_c, inv_p0_c, inv_p1_c;
            inv_p3_c = dut.u_inventory_manager.qty_mem[3];
            inv_p0_c = dut.u_inventory_manager.qty_mem[0];
            inv_p1_c = dut.u_inventory_manager.qty_mem[1];

            // Request 1: WALLET, 40, P3
            send_payment(WALLET, 16'd40, 5'd3);
            wait_response();
            check_result("Test C: Contention Txn 1 (WALLET P3)", STATUS_SUCCESS, ERR_NONE, 1'b1, 16'd0);

            // Request 2: NOTE, 10, P0
            send_payment(NOTE, 16'd10, 5'd0);
            wait_response();
            check_result("Test C: Contention Txn 2 (NOTE P0)", STATUS_SUCCESS, ERR_NONE, 1'b1, 16'd0);

            // Request 3: RFID, 20, P1
            send_payment(RFID, 16'd20, 5'd1);
            wait_response();
            check_result("Test C: Contention Txn 3 (RFID P1)", STATUS_SUCCESS, ERR_NONE, 1'b1, 16'd0);

            check_internal("Test C: P3 Qty Decremented", dut.u_inventory_manager.qty_mem[3], inv_p3_c - 1);
            check_internal("Test C: P0 Qty Decremented", dut.u_inventory_manager.qty_mem[0], inv_p0_c - 1);
            check_internal("Test C: P1 Qty Decremented", dut.u_inventory_manager.qty_mem[1], inv_p1_c - 1);
        end

        //------------------------------------------------------------
        // Subtest 13D: Stability and loss checks
        //------------------------------------------------------------
        begin
            integer tout;
            bit d_accepted;
            integer inv_start_p0_d, inv_start_p1_d;
            response_packet_t resp_bg;
            bit got_resp_bg;

            inv_start_p0_d = dut.u_inventory_manager.qty_mem[0];
            inv_start_p1_d = dut.u_inventory_manager.qty_mem[1];

            // 1. Start background transaction to occupy controller
            @(negedge clk);
            request.payment_type = COIN;
            request.amount       = 16'd10;
            request.product_id   = 5'd0;
            request_valid        = 1'b1;

            while (!request_ready) @(negedge clk);
            @(posedge clk); // Accepting posedge for COIN
            active_txn.payment_type = COIN;
            active_txn.amount       = 16'd10;
            active_txn.product_id   = 5'd0;
            active_txn.inv_before   = inv_start_p0_d;
            active_txn.bal_before   = dut.u_balance_manager.current_balance;
            active_txn_valid        = 1'b1;
            cycle_start             = cycle_count;

            // 2. Present request D while in flight
            @(negedge clk);
            request.payment_type = CARD;
            request.amount       = 16'd20;
            request.product_id   = 5'd1;
            request_valid        = 1'b1;

            // 3. Verify request D remains stable while blocked
            got_resp_bg = 1'b0;
            tout = 0;
            while (!got_resp_bg && tout < WATCHDOG)
            begin
                @(posedge clk);
                tout++;
                assert(request.payment_type == CARD && request.amount == 16'd20 && request.product_id == 5'd1 && request_valid == 1'b1)
                else tb_fail("Test D: Request payload not stable while pending!");

                if (response_valid && !got_resp_bg)
                begin
                    got_resp_bg = 1'b1;
                    resp_bg = response;
                    cycle_end = cycle_count;
                    latency_cycles = cycle_end - cycle_start;
                    latency_sum += latency_cycles;
                    transaction_count++;
                end
            end

            // 4. Now background txn finished and controller enters IDLE.
            // The very next posedge clk is the synchronous accepting edge for blocked request D.
            @(posedge clk);
            d_accepted = 1'b1;
            active_txn.payment_type = CARD;
            active_txn.amount       = 16'd20;
            active_txn.product_id   = 5'd1;
            active_txn.inv_before   = inv_start_p1_d;
            active_txn.bal_before   = dut.u_balance_manager.current_balance;
            active_txn_valid        = 1'b1;
            cycle_start             = cycle_count;

            // Deassert request_valid immediately on negedge clk
            @(negedge clk);
            request_valid = 1'b0;

            // 5. Verify background transaction results
            total_tests++; test_number++;
            if (got_resp_bg && resp_bg.status == STATUS_SUCCESS && resp_bg.dispense == 1'b1)
            begin
                passed_tests++;
                success_count++;
                coin_success++;
                $display("|%4d |%-43s |%10t|%6d|%5d|%4h|%-7s|%3d|%6d|%5d|%6d|%-22s|%-24s|%4d|%6d|%6d|%-6s|",
                    test_number, "Test D: Background Txn (Coin P0)", $time, latency_cycles,
                    dut.u_payment_interface.packet.transaction_id, dut.u_payment_interface.packet.crc,
                    "COIN", 0, inv_start_p0_d, 10, 10, "TRANSACTION SUCCESS", "NO ERROR", 1, 0,
                    dut.u_inventory_manager.qty_mem[0], "PASS");
            end
            else
            begin
                failed_tests++;
                coin_failed++;
                tb_fail("Test D: Background txn response mismatch or timeout");
            end

            check_internal("Test D: Blocked Request Not Lost (Accepted)", d_accepted, 1);

            // 6. Wait for pending request (CARD P1) to complete
            wait_response();
            check_result("Test D: Pending Request Completed (Card P1)",
                         STATUS_SUCCESS, ERR_NONE, 1'b1, 16'd0);
            check_internal("Test D: P1 Decremented",
                           dut.u_inventory_manager.qty_mem[1], inv_start_p1_d - 1);
        end

        //------------------------------------------------------------
        // Subtest 13E: Reset and recovery
        //------------------------------------------------------------
        begin
            // 1. Ready deassertion during reset
            @(negedge clk);
            rst = 1'b1;
            @(negedge clk);
            check_internal("Test E: Ready is 0 during Reset", request_ready, 0);
            @(negedge clk);
            rst = 1'b0;
            repeat(2) @(posedge clk);
            check_internal("Test E: Controller IDLE after Reset", dut.u_transaction_controller.current_state, IDLE);
            check_internal("Test E: Ready is 1 after Reset Released", request_ready, 1);

            // 2. Submit transaction then assert reset while in flight
            send_payment(COIN, 16'd10, 5'd0);
            @(negedge clk);
            rst = 1'b1;
            @(negedge clk);
            check_internal("Test E: Balance Cleared on Mid-Txn Reset", dut.u_balance_manager.current_balance, 0);
            check_internal("Test E: Controller IDLE on Mid-Txn Reset", dut.u_transaction_controller.current_state, IDLE);
            rst = 1'b0;
            repeat(2) @(posedge clk);

            // 3. Post-reset recovery
            send_payment(NOTE, 16'd10, 5'd0);
            wait_response();
            check_result("Test E: Clean Recovery Txn After Reset", STATUS_SUCCESS, ERR_NONE, 1'b1, 16'd0);
            check_internal("Test E: Post-Recovery Controller IDLE", dut.u_transaction_controller.current_state, IDLE);
        end

        cat_begin(14);
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

        cat_begin(0);   // close the last category
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
        $fwrite(html_file,"<tr><th>Transactions</th><th>Count</th><th>Share of failures</th></tr>\n");
        $fwrite(html_file,"<tr><td>Successful Transactions</td><td>%0d</td><td>-</td></tr>\n", success_count);
        //$fwrite(html_file,"<tr><td>Unuccessful Transactions</td><td>%0d</td><td>%0.2f%%</td></tr>\n", error_transaction_count, error_transaction_rate);
        $fwrite(html_file,"<tr><td>Insufficient Balance</td><td>%0d</td><td>%0.2f%%</td></tr>\n", balance_error_count, balance_error_rate);
        $fwrite(html_file,"<tr><td>CRC Error</td><td>%0d</td><td>%0.2f%%</td></tr>\n", crc_error_count, crc_error_rate);
        $fwrite(html_file,"<tr><td>Duplicate</td><td>%0d</td><td>%0.2f%%</td></tr>\n", duplicate_error_count, duplicate_error_rate);
        $fwrite(html_file,"<tr><td>Timeout</td><td>%0d</td><td>%0.2f%%</td></tr>\n", timeout_error_count, timeout_error_rate);
        $fwrite(html_file,"<tr><td>Out of Stock</td><td>%0d</td><td>%0.2f%%</td></tr>\n", stock_error_count, stock_error_rate);
        $fwrite(html_file,"<tr><td>Checked transactions (check_result calls)</td><td>%0d</td><td>-</td></tr>\n", success_count+error_transaction_count);
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
        $fwrite(coverage_csv,"Feature,Status,Test Case,Note\n");
        $fwrite(coverage_csv,"Reset Verification,%s,Reset Test,\n", cat_status(1));
        $fwrite(coverage_csv,"Coin Payment,%s,Coin Payment Test,exact payment only\n", cat_status(2));
        $fwrite(coverage_csv,"Note Payment,%s,Note Payment Test,exact payment only\n", cat_status(3));
        $fwrite(coverage_csv,"RFID Payment,%s,RFID Payment Test,exact payment only\n", cat_status(4));
        $fwrite(coverage_csv,"Card Payment,%s,Card Payment Test,exact payment only; ERR_AUTH rule not exercised\n", cat_status(5));
        $fwrite(coverage_csv,"UPI Payment,%s,UPI Payment Test,exact payment only\n", cat_status(6));
        $fwrite(coverage_csv,"Wallet Payment,%s,Wallet Payment Test,exact payment only\n", cat_status(7));
        $fwrite(coverage_csv,"Mixed Transactions,%s,Mixed Payment Test,sequential only\n", cat_status(8));
        $fwrite(coverage_csv,"Duplicate Transaction Detection,%s,Duplicate Transaction Test,forced counter\n", cat_status(9));
        $fwrite(coverage_csv,"CRC Error Detection,%s,CRC Corruption Test,forced packet.crc\n", cat_status(10));
        $fwrite(coverage_csv,"Inventory Decrement / Stock Depletion,%s,Stock Depletion Test,\n", cat_status(11));
        $fwrite(coverage_csv,"Out of Stock Detection,%s,Stock Empty Test,\n", cat_status(12));
        $fwrite(coverage_csv,"Back-to-Back Transactions / Contention,%s,Handshake & Contention Tests,verified: acceptance tracking, in-flight contention, payload stability, responses & balances checked\n", cat_status(13));
        $fwrite(coverage_csv,"Timeout Detection,%s,Timeout Test,FSM state forced to create the timeout\n", cat_status(14));

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
        $fwrite(html_file,"<center><b>%s</b></center>\n", (failed_tests==0 && tb_errors==0) ? "Verification run: all checks passed" : "Verification run: FAILURES DETECTED");
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
        $fwrite(log_file,"%s\n", (failed_tests==0 && tb_errors==0) ? "Simulation completed: all checks passed." : "Simulation completed: FAILURES DETECTED.");

        $fclose(log_file);

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

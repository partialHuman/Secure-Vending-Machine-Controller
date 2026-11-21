`timescale 1ns/1ps

module tb_inventory_manager;

    import transaction_pkg::*;

    localparam int QTY_WIDTH = INVENTORY_WIDTH;

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
            $display("[INV_TEST PASS] %s", desc);
        end else begin
            failed_tests++;
            tb_errors++;
            $error("[INV_TEST FAIL] %s", desc);
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
    // Primary DUT signals (PRODUCT_COUNT = 5)
    //------------------------------------------------------------
    logic [PRODUCT_ID_WIDTH-1:0] dut_id;
    logic                        dut_read_en;
    logic                        dut_purchase_en;
    logic                        dut_update_price;
    logic                        dut_update_qty;
    logic [PRICE_WIDTH-1:0]      dut_new_price;
    logic [QTY_WIDTH-1:0]        dut_new_qty;
    logic [PRICE_WIDTH-1:0]      dut_price;
    logic [QTY_WIDTH-1:0]        dut_qty;
    logic                        dut_stock_avail;
    logic                        dut_stock_ok;
    logic                        dut_low_stock;

    inventory_manager #(
        .PRODUCT_COUNT(5),
        .PRICE_WIDTH(PRICE_WIDTH),
        .QTY_WIDTH(QTY_WIDTH)
    ) dut_5 (
        .clk(clk),
        .rst(rst),
        .product_id(dut_id),
        .read_en(dut_read_en),
        .purchase_en(dut_purchase_en),
        .update_price(dut_update_price),
        .update_qty(dut_update_qty),
        .new_price(dut_new_price),
        .new_qty(dut_new_qty),
        .product_price(dut_price),
        .quantity(dut_qty),
        .stock_available(dut_stock_avail),
        .stock_ok(dut_stock_ok),
        .low_stock(dut_low_stock)
    );

    //------------------------------------------------------------
    // Secondary DUT instances for multi-count verification
    //------------------------------------------------------------
    // Count = 1
    logic [PRODUCT_ID_WIDTH-1:0] c1_id;
    logic                        c1_read_en, c1_purchase_en, c1_update_price, c1_update_qty;
    logic [PRICE_WIDTH-1:0]      c1_new_price, c1_price;
    logic [QTY_WIDTH-1:0]        c1_new_qty, c1_qty;
    logic                        c1_stock_avail, c1_stock_ok, c1_low_stock;

    inventory_manager #(
        .PRODUCT_COUNT(1)
    ) dut_1 (
        .clk(clk),
        .rst(rst),
        .product_id(c1_id),
        .read_en(c1_read_en),
        .purchase_en(c1_purchase_en),
        .update_price(c1_update_price),
        .update_qty(c1_update_qty),
        .new_price(c1_new_price),
        .new_qty(c1_new_qty),
        .product_price(c1_price),
        .quantity(c1_qty),
        .stock_available(c1_stock_avail),
        .stock_ok(c1_stock_ok),
        .low_stock(c1_low_stock)
    );

    // Count = 4
    logic [PRODUCT_ID_WIDTH-1:0] c4_id;
    logic                        c4_read_en, c4_purchase_en, c4_update_price, c4_update_qty;
    logic [PRICE_WIDTH-1:0]      c4_new_price, c4_price;
    logic [QTY_WIDTH-1:0]        c4_new_qty, c4_qty;
    logic                        c4_stock_avail, c4_stock_ok, c4_low_stock;

    inventory_manager #(
        .PRODUCT_COUNT(4)
    ) dut_4 (
        .clk(clk),
        .rst(rst),
        .product_id(c4_id),
        .read_en(c4_read_en),
        .purchase_en(c4_purchase_en),
        .update_price(c4_update_price),
        .update_qty(c4_update_qty),
        .new_price(c4_new_price),
        .new_qty(c4_new_qty),
        .product_price(c4_price),
        .quantity(c4_qty),
        .stock_available(c4_stock_avail),
        .stock_ok(c4_stock_ok),
        .low_stock(c4_low_stock)
    );

    // Count = 8
    logic [PRODUCT_ID_WIDTH-1:0] c8_id;
    logic                        c8_read_en, c8_purchase_en, c8_update_price, c8_update_qty;
    logic [PRICE_WIDTH-1:0]      c8_new_price, c8_price;
    logic [QTY_WIDTH-1:0]        c8_new_qty, c8_qty;
    logic                        c8_stock_avail, c8_stock_ok, c8_low_stock;

    inventory_manager #(
        .PRODUCT_COUNT(8)
    ) dut_8 (
        .clk(clk),
        .rst(rst),
        .product_id(c8_id),
        .read_en(c8_read_en),
        .purchase_en(c8_purchase_en),
        .update_price(c8_update_price),
        .update_qty(c8_update_qty),
        .new_price(c8_new_price),
        .new_qty(c8_new_qty),
        .product_price(c8_price),
        .quantity(c8_qty),
        .stock_available(c8_stock_avail),
        .stock_ok(c8_stock_ok),
        .low_stock(c8_low_stock)
    );

    // Count = 32
    logic [PRODUCT_ID_WIDTH-1:0] c32_id;
    logic                        c32_read_en, c32_purchase_en, c32_update_price, c32_update_qty;
    logic [PRICE_WIDTH-1:0]      c32_new_price, c32_price;
    logic [QTY_WIDTH-1:0]        c32_new_qty, c32_qty;
    logic                        c32_stock_avail, c32_stock_ok, c32_low_stock;

    inventory_manager #(
        .PRODUCT_COUNT(32)
    ) dut_32 (
        .clk(clk),
        .rst(rst),
        .product_id(c32_id),
        .read_en(c32_read_en),
        .purchase_en(c32_purchase_en),
        .update_price(c32_update_price),
        .update_qty(c32_update_qty),
        .new_price(c32_new_price),
        .new_qty(c32_new_qty),
        .product_price(c32_price),
        .quantity(c32_qty),
        .stock_available(c32_stock_avail),
        .stock_ok(c32_stock_ok),
        .low_stock(c32_low_stock)
    );

    //------------------------------------------------------------
    // Snapshot arrays for checking memory integrity
    //------------------------------------------------------------
    logic [PRICE_WIDTH-1:0] snap_price_5 [0:4];
    logic [QTY_WIDTH-1:0]   snap_qty_5   [0:4];

    task automatic take_snapshot_5();
        integer idx;
        for (idx = 0; idx < 5; idx = idx + 1) begin
            snap_price_5[idx] = dut_5.price_mem[idx];
            snap_qty_5[idx]   = dut_5.qty_mem[idx];
        end
    endtask

    function automatic bit compare_snapshot_5();
        integer idx;
        bit match_ok;
        match_ok = 1'b1;
        for (idx = 0; idx < 5; idx = idx + 1) begin
            if (dut_5.price_mem[idx] !== snap_price_5[idx] ||
                dut_5.qty_mem[idx]   !== snap_qty_5[idx]) begin
                match_ok = 1'b0;
            end
        end
        return match_ok;
    endfunction

    //------------------------------------------------------------
    // Main Test Sequence
    //------------------------------------------------------------
    initial begin
        integer i, k;

        // Initialize control signals
        dut_id           = '0;
        dut_read_en      = 1'b0;
        dut_purchase_en  = 1'b0;
        dut_update_price = 1'b0;
        dut_update_qty   = 1'b0;
        dut_new_price    = '0;
        dut_new_qty      = '0;

        c1_id = '0; c1_read_en = 0; c1_purchase_en = 0; c1_update_price = 0; c1_update_qty = 0; c1_new_price = 0; c1_new_qty = 0;
        c4_id = '0; c4_read_en = 0; c4_purchase_en = 0; c4_update_price = 0; c4_update_qty = 0; c4_new_price = 0; c4_new_qty = 0;
        c8_id = '0; c8_read_en = 0; c8_purchase_en = 0; c8_update_price = 0; c8_update_qty = 0; c8_new_price = 0; c8_new_qty = 0;
        c32_id = '0; c32_read_en = 0; c32_purchase_en = 0; c32_update_price = 0; c32_update_qty = 0; c32_new_price = 0; c32_new_qty = 0;

        // Apply Reset
        rst = 1'b1;
        #20;
        @(negedge clk);
        rst = 1'b0;
        @(posedge clk);
        #1;

        $display("================================================================");
        $display("   INVENTORY MANAGER DIRECT UNIT TESTBENCH (D-103, D-108)");
        $display("================================================================");

        //------------------------------------------------------------
        // SECTION 1: Array Depth & Reset State on dut_5 (PRODUCT_COUNT=5)
        //------------------------------------------------------------
        check_condition("DUT_5: array size qty_mem is 5",   $size(dut_5.qty_mem) == 5);
        check_condition("DUT_5: array size price_mem is 5", $size(dut_5.price_mem) == 5);
        check_condition("DUT_5: array bits qty_mem is 40",  $bits(dut_5.qty_mem) == 40);

        for (i = 0; i < 5; i = i + 1) begin
            check_condition($sformatf("DUT_5: reset price_mem[%0d] == %0d", i, (i+1)*10), dut_5.price_mem[i] == (i+1)*10);
            check_condition($sformatf("DUT_5: reset qty_mem[%0d] == 20", i), dut_5.qty_mem[i] == 20);
        end

        //------------------------------------------------------------
        // SECTION 2: Valid Reads (First ID 0, Last ID 4)
        //------------------------------------------------------------
        // ID 0
        dut_id = 5'd0;
        dut_read_en = 1'b1;
        #1;
        check_condition("DUT_5: read ID 0 price == 10", dut_price == 16'd10);
        check_condition("DUT_5: read ID 0 quantity == 20", dut_qty == 8'd20);
        check_condition("DUT_5: read ID 0 stock_available == 1", dut_stock_avail == 1'b1);
        check_condition("DUT_5: read ID 0 stock_ok == 1", dut_stock_ok == 1'b1);
        check_condition("DUT_5: read ID 0 low_stock == 0", dut_low_stock == 1'b0);

        // ID 4
        dut_id = 5'd4;
        #1;
        check_condition("DUT_5: read ID 4 price == 50", dut_price == 16'd50);
        check_condition("DUT_5: read ID 4 quantity == 20", dut_qty == 8'd20);
        check_condition("DUT_5: read ID 4 stock_available == 1", dut_stock_avail == 1'b1);
        check_condition("DUT_5: read ID 4 stock_ok == 1", dut_stock_ok == 1'b1);
        check_condition("DUT_5: read ID 4 low_stock == 0", dut_low_stock == 1'b0);

        // Read Disabled (read_en = 0 returns safe 0)
        dut_read_en = 1'b0;
        #1;
        check_condition("DUT_5: read_en=0 returns zero price", dut_price == 16'd0);
        check_condition("DUT_5: read_en=0 returns zero quantity", dut_qty == 8'd0);
        check_condition("DUT_5: read_en=0 returns stock_ok=0", dut_stock_ok == 1'b0);

        //------------------------------------------------------------
        // SECTION 3: Invalid Reads Return Safe Zero (ID = 5, ID = 31)
        //------------------------------------------------------------
        // Boundary invalid ID 5 (= PRODUCT_COUNT)
        dut_id = 5'd5;
        dut_read_en = 1'b1;
        #1;
        check_condition("DUT_5: read invalid ID 5 returns price=0", dut_price == 16'd0);
        check_condition("DUT_5: read invalid ID 5 returns quantity=0", dut_qty == 8'd0);
        check_condition("DUT_5: read invalid ID 5 returns stock_available=0", dut_stock_avail == 1'b0);
        check_condition("DUT_5: read invalid ID 5 returns stock_ok=0", dut_stock_ok == 1'b0);
        check_condition("DUT_5: read invalid ID 5 returns low_stock=0", dut_low_stock == 1'b0);

        // Max encodable invalid ID 31
        dut_id = 5'd31;
        #1;
        check_condition("DUT_5: read invalid ID 31 returns price=0", dut_price == 16'd0);
        check_condition("DUT_5: read invalid ID 31 returns quantity=0", dut_qty == 8'd0);
        check_condition("DUT_5: read invalid ID 31 returns stock_available=0", dut_stock_avail == 1'b0);
        check_condition("DUT_5: read invalid ID 31 returns stock_ok=0", dut_stock_ok == 1'b0);
        check_condition("DUT_5: read invalid ID 31 returns low_stock=0", dut_low_stock == 1'b0);
        dut_read_en = 1'b0;

        //------------------------------------------------------------
        // SECTION 4: Invalid Writes Have No Effect (Snapshot verified)
        //------------------------------------------------------------
        // Test with ID = 5
        take_snapshot_5();
        @(negedge clk);
        dut_id = 5'd5;
        dut_update_price = 1'b1;
        dut_new_price    = 16'hAAAA;
        dut_update_qty   = 1'b1;
        dut_new_qty      = 8'h55;
        @(posedge clk);
        #1;
        dut_update_price = 1'b0;
        dut_update_qty   = 1'b0;
        check_condition("DUT_5: invalid write at ID 5 preserves all memory entries", compare_snapshot_5());

        // Test with ID = 31
        take_snapshot_5();
        @(negedge clk);
        dut_id = 5'd31;
        dut_update_price = 1'b1;
        dut_new_price    = 16'hDEAD;
        dut_update_qty   = 1'b1;
        dut_new_qty      = 8'hEE;
        @(posedge clk);
        #1;
        dut_update_price = 1'b0;
        dut_update_qty   = 1'b0;
        check_condition("DUT_5: invalid write at ID 31 preserves all memory entries", compare_snapshot_5());

        //------------------------------------------------------------
        // SECTION 5: Invalid Decrements Have No Effect (Snapshot verified)
        //------------------------------------------------------------
        // Test with ID = 5
        take_snapshot_5();
        @(negedge clk);
        dut_id = 5'd5;
        dut_purchase_en = 1'b1;
        @(posedge clk);
        #1;
        dut_purchase_en = 1'b0;
        check_condition("DUT_5: invalid decrement at ID 5 preserves all memory entries", compare_snapshot_5());

        // Test with ID = 31
        take_snapshot_5();
        @(negedge clk);
        dut_id = 5'd31;
        dut_purchase_en = 1'b1;
        @(posedge clk);
        #1;
        dut_purchase_en = 1'b0;
        check_condition("DUT_5: invalid decrement at ID 31 preserves all memory entries", compare_snapshot_5());

        //------------------------------------------------------------
        // SECTION 6: Battery Across All Invalid IDs (5 through 31)
        //------------------------------------------------------------
        take_snapshot_5();
        for (k = 5; k < 32; k = k + 1) begin
            @(negedge clk);
            dut_id           = k[4:0];
            dut_read_en      = 1'b1;
            dut_purchase_en  = 1'b1;
            dut_update_price = 1'b1;
            dut_new_price    = 16'hBEEF;
            dut_update_qty   = 1'b1;
            dut_new_qty      = 8'h77;
            #1;
            if (dut_price !== 16'd0 || dut_qty !== 8'd0 || dut_stock_avail !== 1'b0) begin
                tb_errors++;
                $error("DUT_5: invalid ID %0d did not return safe zeros", k);
            end
            @(posedge clk);
            #1;
        end
        dut_read_en      = 1'b0;
        dut_purchase_en  = 1'b0;
        dut_update_price = 1'b0;
        dut_update_qty   = 1'b0;
        check_condition("DUT_5: sweep of invalid IDs 5..31 preserved all memory entries", compare_snapshot_5());

        //------------------------------------------------------------
        // SECTION 7: Valid Writes and Decrements Work
        //------------------------------------------------------------
        // Valid update price on ID 0
        @(negedge clk);
        dut_id           = 5'd0;
        dut_update_price = 1'b1;
        dut_new_price    = 16'd99;
        @(posedge clk);
        #1;
        dut_update_price = 1'b0;
        check_condition("DUT_5: valid update_price on ID 0 sets price=99", dut_5.price_mem[0] == 16'd99);

        // Valid update qty on ID 0
        @(negedge clk);
        dut_id         = 5'd0;
        dut_update_qty = 1'b1;
        dut_new_qty    = 8'd15;
        @(posedge clk);
        #1;
        dut_update_qty = 1'b0;
        check_condition("DUT_5: valid update_qty on ID 0 sets qty=15", dut_5.qty_mem[0] == 8'd15);

        // Valid purchase on ID 0 (decrements from 15 to 14)
        @(negedge clk);
        dut_id          = 5'd0;
        dut_purchase_en = 1'b1;
        @(posedge clk);
        #1;
        dut_purchase_en = 1'b0;
        check_condition("DUT_5: valid purchase on ID 0 decrements qty to 14", dut_5.qty_mem[0] == 8'd14);

        // Valid update price & qty on ID 4
        @(negedge clk);
        dut_id           = 5'd4;
        dut_update_price = 1'b1;
        dut_new_price    = 16'd199;
        dut_update_qty   = 1'b1;
        dut_new_qty      = 8'd6;
        @(posedge clk);
        #1;
        dut_update_price = 1'b0;
        dut_update_qty   = 1'b0;
        check_condition("DUT_5: valid update on ID 4 sets price=199", dut_5.price_mem[4] == 16'd199);
        check_condition("DUT_5: valid update on ID 4 sets qty=6", dut_5.qty_mem[4] == 8'd6);

        // Valid purchase on ID 4 (decrements from 6 to 5 -> triggers low_stock)
        @(negedge clk);
        dut_id          = 5'd4;
        dut_purchase_en = 1'b1;
        @(posedge clk);
        #1;
        dut_purchase_en = 1'b0;
        check_condition("DUT_5: valid purchase on ID 4 decrements qty to 5", dut_5.qty_mem[4] == 8'd5);

        dut_read_en = 1'b1;
        #1;
        check_condition("DUT_5: read ID 4 detects low_stock == 1", dut_low_stock == 1'b1);
        dut_read_en = 1'b0;

        // Decrement ID 4 to zero and test underflow guard
        for (k = 0; k < 5; k = k + 1) begin
            @(negedge clk);
            dut_id          = 5'd4;
            dut_purchase_en = 1'b1;
            @(posedge clk);
            #1;
        end
        dut_purchase_en = 1'b0;
        check_condition("DUT_5: ID 4 qty reached 0", dut_5.qty_mem[4] == 8'd0);

        dut_read_en = 1'b1;
        #1;
        check_condition("DUT_5: ID 4 stock_available == 0 when empty", dut_stock_avail == 1'b0);
        check_condition("DUT_5: ID 4 stock_ok == 0 when empty", dut_stock_ok == 1'b0);
        dut_read_en = 1'b0;

        // Attempt purchase when qty == 0
        @(negedge clk);
        dut_purchase_en = 1'b1;
        @(posedge clk);
        #1;
        dut_purchase_en = 1'b0;
        check_condition("DUT_5: ID 4 qty remains 0 on purchase attempt when empty", dut_5.qty_mem[4] == 8'd0);

        //------------------------------------------------------------
        // SECTION 8: Multi-Configuration Array Depth & Guard Tests
        //------------------------------------------------------------
        // DUT_1 (PRODUCT_COUNT = 1)
        check_condition("DUT_1: array size is 1", $size(dut_1.qty_mem) == 1);
        c1_id = 5'd0; c1_read_en = 1'b1; #1;
        check_condition("DUT_1: read ID 0 price == 10", c1_price == 16'd10);
        c1_id = 5'd1; #1;
        check_condition("DUT_1: read invalid ID 1 returns price 0", c1_price == 16'd0);
        c1_id = 5'd31; #1;
        check_condition("DUT_1: read invalid ID 31 returns price 0", c1_price == 16'd0);
        c1_read_en = 1'b0;

        // DUT_4 (PRODUCT_COUNT = 4)
        check_condition("DUT_4: array size is 4", $size(dut_4.qty_mem) == 4);
        c4_id = 5'd3; c4_read_en = 1'b1; #1;
        check_condition("DUT_4: read ID 3 price == 40", c4_price == 16'd40);
        c4_id = 5'd4; #1;
        check_condition("DUT_4: read invalid ID 4 returns price 0", c4_price == 16'd0);
        c4_read_en = 1'b0;

        // DUT_8 (PRODUCT_COUNT = 8)
        check_condition("DUT_8: array size is 8", $size(dut_8.qty_mem) == 8);
        c8_id = 5'd7; c8_read_en = 1'b1; #1;
        check_condition("DUT_8: read ID 7 price == 80", c8_price == 16'd80);
        c8_id = 5'd8; #1;
        check_condition("DUT_8: read invalid ID 8 returns price 0", c8_price == 16'd0);
        c8_read_en = 1'b0;

        // DUT_32 (PRODUCT_COUNT = 32)
        check_condition("DUT_32: array size is 32", $size(dut_32.qty_mem) == 32);
        c32_id = 5'd31; c32_read_en = 1'b1; #1;
        check_condition("DUT_32: read ID 31 price == 320", c32_price == 16'd320);
        check_condition("DUT_32: read ID 31 qty == 20", c32_qty == 8'd20);
        c32_read_en = 1'b0;

        //------------------------------------------------------------
        // Testbench Summary & Marker
        //------------------------------------------------------------
        $display("================================================================");
        $display("   INVENTORY MANAGER TESTBENCH SUMMARY");
        $display("================================================================");
        $display("Total Checks : %0d", total_tests);
        $display("Passed Checks: %0d", passed_tests);
        $display("Failed Checks: %0d", failed_tests);
        $display("TB Errors    : %0d", tb_errors);
        $display("================================================================");

        if (failed_tests != 0 || tb_errors != 0) begin
            $display("SVM_TB_RESULT: FAIL total=%0d passed=%0d failed=%0d tb_errors=%0d",
                     total_tests, passed_tests, failed_tests, tb_errors);
            $fatal(1, "tb_inventory_manager reported failures");
        end else begin
            $display("SVM_TB_RESULT: PASS total=%0d passed=%0d failed=%0d tb_errors=%0d",
                     total_tests, passed_tests, failed_tests, tb_errors);
            $finish;
        end
    end

endmodule

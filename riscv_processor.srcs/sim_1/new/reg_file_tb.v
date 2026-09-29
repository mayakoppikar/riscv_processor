`timescale 1ns / 1ps

module tb_reg_file();
    reg clk, rst, ld_reg;
    reg [4:0] sr1, sr2, dr;
    reg [31:0] bus_in;
    wire [31:0] sr1_out;
    wire [31:0] sr2_out;

    reg_file uut (
        .clk(clk),
        .rst(rst),
        .ld_reg(ld_reg),
        .sr1(sr1),
        .sr2(sr2),
        .bus_in(bus_in),
        .dr(dr),
        .sr1_out(sr1_out),
        .sr2_out(sr2_out)
    );

    // Clock Generation (100MHz -> 10ns period)
    always #5 clk = ~clk;

    initial begin
        clk = 0;
        rst = 0;
        ld_reg = 0;
        sr1 = 5'd0;
        sr2 = 5'd0;
        dr = 5'd0;
        bus_in = 32'd0;

        // -------------------------------------------------------------
        // TEST 1: Active-High Reset Verification
        // -------------------------------------------------------------
        $display("--- TEST 1: Asserting Reset ---");
        #2;
        rst = 1;
        #10;
        rst = 0;
        #5;
        
        // Verify sr1 and sr2 read zero
        sr1 = 5'd5;
        sr2 = 5'd10;
        #2;
        if (sr1_out === 32'd0 && sr2_out === 32'd0)
            $display("[PASS] Reset cleared all registers correctly.");
        else
            $display("[FAIL] Reset failed. sr1_out = %h, sr2_out = %h", sr1_out, sr2_out);

        // -------------------------------------------------------------
        // TEST 2: Write to Register x1 and x2, then Read back
        // -------------------------------------------------------------
        $display("\n--- TEST 2: Writing and Reading x1 and x2 ---");
        
        // Write 0xDEADBEEF to x1
        @(posedge clk);
        ld_reg = 1;
        dr = 5'd1;
        bus_in = 32'hDEADBEEF;

        // Write 0x12345678 to x2
        @(posedge clk);
        dr = 5'd2;
        bus_in = 32'h12345678;

        // Turn off write enable and point read ports to x1 and x2
        @(posedge clk);
        ld_reg = 0;
        sr1 = 5'd1;
        sr2 = 5'd2;
        #2;

        if (sr1_out === 32'hDEADBEEF && sr2_out === 32'h12345678)
            $display("[PASS] Read x1 = %h, x2 = %h successfully.", sr1_out, sr2_out);
        else
            $display("[FAIL] Readback mismatch! sr1_out = %h, sr2_out = %h", sr1_out, sr2_out);

        // -------------------------------------------------------------
        // TEST 3: Attempt Write to Register x0 (Should Remain 0)
        // -------------------------------------------------------------
        $display("\n--- TEST 3: Attempting Write to x0 ---");
        
        @(posedge clk);
        ld_reg = 1;
        dr = 5'd0; // Destination x0
        bus_in = 32'hFFFFFFFF;

        @(posedge clk);
        ld_reg = 0;
        sr1 = 5'd0; // Read x0
        #2;

        if (sr1_out === 32'h00000000)
            $display("[PASS] x0 correctly protected from write. sr1_out = %h", sr1_out);
        else
            $display("[FAIL] x0 was modified! sr1_out = %h", sr1_out);

        // -------------------------------------------------------------
        // TEST 4: Ensure ld_reg = 0 Prevents Register Writes
        // -------------------------------------------------------------
        $display("\n--- TEST 4: Checking ld_reg = 0 Behavior ---");
        
        @(posedge clk);
        ld_reg = 0; // Disable write
        dr = 5'd1;
        bus_in = 32'hCAFECAFE;

        @(posedge clk);
        sr1 = 5'd1; // Read x1
        #2;

        if (sr1_out === 32'hDEADBEEF)
            $display("[PASS] Register x1 unchanged when ld_reg = 0.");
        else
            $display("[FAIL] Register x1 modified without ld_reg! sr1_out = %h", sr1_out);

        $display("\n--- All Tests Complete ---");
        $finish;
    end

endmodule
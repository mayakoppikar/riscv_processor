`timescale 1ns / 1ps

module memory_tb;

    // Parameters (12 bits = 4096 bytes)
    parameter ADDR_WIDTH = 12; 
    parameter DATA_WIDTH = 32;

    // Testbench Signals
    reg clk;
    reg cs;
    reg we;
    reg [1:0] size_sel;
    reg [31:0] mar_addr;
    reg [31:0] din;
    wire [31:0] dout;

    // Instantiate the Unit Under Test (UUT)
    memory #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) uut (
        .clk(clk),
        .cs(cs),
        .we(we),
        .size_sel(size_sel),
        .mar_addr(mar_addr),
        .din(din),
        .dout(dout)
    );

    // Clock Generation: 10ns period (100 MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Test Sequence
    initial begin
        // Initialize Inputs
        cs = 0;
        we = 0;
        size_sel = 2'b10;
        mar_addr = 32'h0;
        din = 32'h0;

        // Allow memory to settle after initial block clearing
        #20;
        
        $display("\n==============================================");
        $display("   STARTING ADVANCED CORNER-CASE MEMORY TB    ");
        $display("==============================================");

        // -----------------------------------------------------------------
        // TEST 1: Full Word Write and Read (sw / lw style)
        // -----------------------------------------------------------------
        @(posedge clk);
        cs = 1; we = 1; size_sel = 2'b10;
        mar_addr = 32'h0000_0004; 
        din = 32'hA5A5_5A5A;
        
        @(posedge clk);
        we = 0;
        mar_addr = 32'h0000_0004; // Restored base address
        #1;
        $display("[Test 1 - Word RW] Addr: 0x04 | Read Dout: 0x%h (Expected: 0xA5A55A5A)", dout);
        if (dout !== 32'hA5A55A5A) $error("FAIL: Word Read mismatch!");

        // -----------------------------------------------------------------
        // TEST 2: All 4 Byte Lanes via Byte Store (`sb`)
        // -----------------------------------------------------------------
        // Initialize word at byte address 0x20 to all zeros
        @(posedge clk);
        cs = 1; we = 1; size_sel = 2'b10;
        mar_addr = 32'h0000_0020;
        din = 32'h0000_0000;

        // Populate byte 0 (offset 0)
        @(posedge clk);
        size_sel = 2'b00; mar_addr = 32'h0000_0020; din = 32'h0000_0011;
        // Populate byte 1 (offset 1)
        @(posedge clk);
        mar_addr = 32'h0000_0021; din = 32'h0000_0022;
        // Populate byte 2 (offset 2)
        @(posedge clk);
        mar_addr = 32'h0000_0022; din = 32'h0000_0033;
        // Populate byte 3 (offset 3)
        @(posedge clk);
        mar_addr = 32'h0000_0023; din = 32'h0000_0044;

        // Read back and verify Little-Endian construction: {04, 03, 02, 01} -> 0x44332211
        @(posedge clk);
        mar_addr = 32'h0000_0020;
        we = 0;
        #1;
        $display("[Test 2 - All Bytes] Addr: 0x20 | Read Dout: 0x%h (Expected: 0x44332211)", dout);
        if (dout !== 32'h44332211) $error("FAIL: Byte lane population failed!");

        // -----------------------------------------------------------------
        // TEST 3: Halfword Store (`sh`) Upper vs Lower Boundary
        // -----------------------------------------------------------------
        // Init base word at 0x40 to 0x11223344
        @(posedge clk);
        cs = 1; we = 1; size_sel = 2'b10;
        mar_addr = 32'h0000_0040;
        din = 32'h11223344;

        // Overwrite lower halfword (bytes at 0x40, 0x41) with 0xFFFF
        @(posedge clk);
        size_sel = 2'b01; mar_addr = 32'h0000_0040; din = 32'h0000_FFFF;

        // Verify result (Expect upper half 0x1122 untouched, lower half 0xFFFF) -> 0x1122FFFF
        @(posedge clk);
        mar_addr = 32'h0000_0040;
        we = 0;
        #1;
        $display("[Test 3 - Halfword Lower] Addr: 0x40 | Read Dout: 0x%h (Expected: 0x1122FFFF)", dout);
        if (dout !== 32'h1122FFFF) $error("FAIL: Lower halfword store failed!");

        // Overwrite upper halfword (bytes at 0x42, 0x43) with 0xAAAA
        @(posedge clk);
        cs = 1; we = 1; size_sel = 2'b01;
        mar_addr = 32'h0000_0042;
        din = 32'h0000_AAAA;

        // Verify result -> 0xAAAAFFFF
        @(posedge clk);
        mar_addr = 32'h0000_0040;
        we = 0;
        #1;
        $display("[Test 3 - Halfword Upper] Addr: 0x40 | Read Dout: 0x%h (Expected: 0xAAAAFFFF)", dout);
        if (dout !== 32'hAAAAFFFF) $error("FAIL: Upper halfword store failed!");

        // -----------------------------------------------------------------
        // TEST 4: Chip Select (`cs`) Gating Protection
        // -----------------------------------------------------------------
        // Try writing with cs = 0 (should be completely ignored)
        @(posedge clk);
        cs = 0; we = 1; size_sel = 2'b10;
        mar_addr = 32'h0000_0050;
        din = 32'hDEAD_BEEF;

        // Read back from 0x50 (should be default initialized zero, not DEADBEEF)
        @(posedge clk);
        cs = 1; we = 0;
        mar_addr = 32'h0000_0050;
        #1;
        $display("[Test 4 - CS Low Write-Protect] Addr: 0x50 | Read Dout: 0x%h (Expected: 0x00000000)", dout);
        if (dout !== 32'h0000_0000) $error("FAIL: CS low failed to block write!");

        // Try reading with cs = 0 (dout must force to 0)
        @(posedge clk);
        cs = 0; we = 0;
        mar_addr = 32'h0000_0050;
        #1;
        $display("[Test 4 - CS Low Read-Gating] Read Dout: 0x%h (Expected: 0x00000000)", dout);
        if (dout !== 32'h0000_0000) $error("FAIL: CS low failed to zero dout!");

        // -----------------------------------------------------------------
        // TEST 5: Write Enable (`we = 0`) Safety Check
        // -----------------------------------------------------------------
        // Setup a known value at 0x60
        @(posedge clk);
        cs = 1; we = 1; size_sel = 2'b10;
        mar_addr = 32'h0000_0060;
        din = 32'h1234_5678;

        // Keep cs=1, but set we=0 and try to "write" garbage data
        @(posedge clk);
        we = 0; // Read mode
        mar_addr = 32'h0000_0060;
        din = 32'hFFFF_FFFF; // Should be ignored because we=0

        // Verify data at 0x60 is still original value
        #1;
        $display("[Test 5 - WE Low Safety] Addr: 0x60 | Read Dout: 0x%h (Expected: 0x12345678)", dout);
        if (dout !== 32'h1234_5678) $error("FAIL: Memory mutated while we=0!");

        // -----------------------------------------------------------------
        // TEST 6: High-Address Boundary Check (Near 4 KB Limit)
        // -----------------------------------------------------------------
        // 4096 bytes max -> max word aligned address is 4092 (0xFFC)
        @(posedge clk);
        cs = 1; we = 1; size_sel = 2'b10;
        mar_addr = 32'h0000_0FFC; 
        din = 32'hCAFE_BABE;

        @(posedge clk);
        mar_addr = 32'h0000_0FFC;
        we = 0;
        #1;
        $display("[Test 6 - High Boundary] Addr: 0xFFC | Read Dout: 0x%h (Expected: 0xCAFEBABE)", dout);
        if (dout !== 32'hCAFEBABE) $error("FAIL: High address boundary write/read failed!");

        // -----------------------------------------------------------------
        // TEST 7: Interleaved Mixed-Size Stress Test
        // -----------------------------------------------------------------
        // Step 1: Write base word 0x00000000 at 0x80
        @(posedge clk);
        cs = 1; we = 1; size_sel = 2'b10; mar_addr = 32'h0000_0080; din = 32'h0000_0000;
        // Step 2: Store word using size_sel = 2'b11 (alias case)
        @(posedge clk);
        size_sel = 2'b11; mar_addr = 32'h0000_0080; din = 32'h8765_4321;
        
        @(posedge clk);
        mar_addr = 32'h0000_0080; we = 0;
        #1;
        $display("[Test 7 - Alias Size Match] Addr: 0x80 | Read Dout: 0x%h (Expected: 0x87654321)", dout);
        if (dout !== 32'h87654321) $error("FAIL: Size selector alias case failed!");

        #20;
        $display("==============================================");
        $display("   ALL CORNER-CASE TESTS PASSED CLEANLY!      ");
        $display("==============================================");
        $finish;
    end

endmodule
`timescale 1ns / 1ps

module tb_multi_cycle_riscv();

    // Inputs
    reg clk;
    reg rst;

    // Instantiate the Unit Under Test (UUT)
    multi_cycle_riscv uut (
        .clk(clk), 
        .rst(rst)
    );

    // Clock generation: 10ns period (50MHz)
    always #5 clk = ~clk;

    integer i;

    initial begin
        // Initialize signals
        clk = 0;
        rst = 1;

        // 1. Clear all registers to 0 in the register file instance
        // (Ensure 'regs' matches the array name inside reg_file.v)
//        for (i = 0; i < 32; i = i + 1) begin
//            uut.rf_multi.regs[i] = 32'h00000000;
//        end

        // 2. Load instructions into memory 
        // Note: Updated from .RAM to .MEM to match your memory.v module declaration
        $readmemh("simple_addition.mem", uut.mem_multi.MEM);
        $display("[TB] Memory initialized from simple_addition.mem");

        // Hold reset for 20ns
        #20;
        rst = 0;
        $display("[TB] Reset released, starting execution...");

        // Run simulation long enough for instructions to execute 
        // (3 instructions * ~5 cycles each = ~150ns)
        #975
        
$display("--- Final Register File Dump ---");
        for (i = 0; i < 32; i = i + 1) begin
            $display("r%0d = %0d (0x%h)", i, uut.rf_multi.REG[i], uut.rf_multi.REG[i]);
        end
        $display("--- Simulation Finished ---");
        $finish;
        
        $display("--- Simulation Finished ---");
        $finish;
    end

    // Monitor state changes in the console as it runs
    initial begin
        $monitor("Time=%0t ns | State=%0d | PC=%h | IR=%h | ALU_Out=%h | Mar=%h | MDR=%h", 
                 $time, uut.state, uut.pc, uut.ir, uut.alu_out, uut.mar, uut.mdr);
    end

endmodule
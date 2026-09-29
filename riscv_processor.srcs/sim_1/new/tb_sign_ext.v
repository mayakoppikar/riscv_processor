`timescale 1ns / 1ps

module tb_sign_ext();

    // Inputs
    reg [31:0] ir;

    // Outputs
    wire [31:0] sext_out;

    // Instantiate Unit Under Test (UUT)
    sign_ext uut (
        .ir(ir),
        .sext_out(sext_out)
    );

    // Self-checking verification task
    task check_output;
        input [31:0] test_ir;
        input [31:0] expected_out;
        input [127:0] type_name; // String label for display
        begin
            ir = test_ir;
            #10; // Wait for combinational propagation
            
            if (sext_out !== expected_out) begin
                $display("[FAIL %0s] IR: %h | Got: %h | Expected: %h", 
                         type_name, test_ir, sext_out, expected_out);
            end else begin
                $display("[PASS %0s] IR: %h -> Imm: %h", 
                         type_name, test_ir, sext_out);
            end
        end
    endtask

    initial begin
        $display("--- Starting Sign-Extension Unit Verification ---");

        // 1. I-Type Test (Opcode: 7'b0010011 -> ADDI) 
        // Imm = 12'hFFF (-1) -> 32'hFFFF_FFFF
        check_output(32'hFFF00093, 32'hFFFF_FFFF, "I-Type Neg");
        // Imm = 12'h02A (42) -> 32'h0000_002A
        check_output(32'h02A00093, 32'h0000_002A, "I-Type Pos");

        // 2. S-Type Test (Opcode: 7'b0100011 -> SW) 
        // Imm = 12'hFFC (-4) split in IR -> 32'hFFFF_FFFC
        check_output(32'hFE112E23, 32'hFFFF_FFFC, "S-Type Neg");

        // 3. B-Type Test (Opcode: 7'b1100011 -> BEQ) 
        // Offset -8 (bit 0 is implicitly 0) -> 32'hFFFF_FFF8
        check_output(32'hFE008CE3, 32'hFFFF_FFF8, "B-Type Neg");

        // 4. U-Type Test (Opcode: 7'b0110111 -> LUI) 
        // Imm = 32'h1234_5000
        check_output(32'h123450B7, 32'h1234_5000, "U-Type");

        // 5. J-Type Test (Opcode: 7'b1101111 -> JAL) 
        // Offset -2 (bit 0 is implicitly 0) -> 32'hFFFF_FFFE
        check_output(32'hFFFF_F0EF, 32'hFFFF_FFFE, "J-Type Neg");

        $display("--- Verification Complete ---");
        $finish;
    end

endmodule
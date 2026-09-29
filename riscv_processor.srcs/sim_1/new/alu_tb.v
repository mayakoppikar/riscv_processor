`timescale 1ns / 1ps

module alu_tb();

    reg [31:0] in_a, in_b;
    reg [31:0] ir;
    wire [31:0] alu_out;
    wire N, Z, C, V;

    // Instantiate the ALU
    alu uut (
        .in_a(in_a), 
        .in_b(in_b), 
        .ir(ir), 
        .alu_out(alu_out), 
        .N(N), 
        .Z(Z), 
        .C(C), 
        .V(V)
    );

    initial begin
        $display("=== STARTING FULL ALU INSTRUCTION TESTBENCH ===");

        // ==========================================
        // R-TYPE INSTRUCTIONS
        // Format: {funct7(7), rs2(5), rs1(5), funct3(3), rd(5), opcode(7)}
        // Opcode: 7'b0110011
        // ==========================================

        // 1. ADD (funct3 = 000, funct7 = 0000000)
        ir   = {7'b0000000, 5'd2, 5'd1, 3'b000, 5'd3, 7'b0110011};
        in_a = 32'd20; in_b = 32'd10; #10;
        if (alu_out === 32'd30) $display("[PASS] ADD"); else $display("[FAIL] ADD: Got %0d", alu_out);

        // 2. SUB (funct3 = 000, funct7 = 0100000)
        ir   = {7'b0100000, 5'd2, 5'd1, 3'b000, 5'd3, 7'b0110011};
        in_a = 32'd20; in_b = 32'd10; #10;
        if (alu_out === 32'd10) $display("[PASS] SUB"); else $display("[FAIL] SUB: Got %0d", alu_out);

        // 3. SLL (funct3 = 001, funct7 = 0000000)
        ir   = {7'b0000000, 5'd2, 5'd1, 3'b001, 5'd3, 7'b0110011};
        in_a = 32'd2; in_b = 32'd3; #10;
        if (alu_out === 32'd16) $display("[PASS] SLL"); else $display("[FAIL] SLL: Got %0d", alu_out);

        // 4. SLT (funct3 = 010, funct7 = 0000000) -> 5 < 10 (True)
        ir   = {7'b0000000, 5'd2, 5'd1, 3'b010, 5'd3, 7'b0110011};
        in_a = 32'd5; in_b = 32'd10; #10;
        if (alu_out === 32'd1) $display("[PASS] SLT"); else $display("[FAIL] SLT: Got %0d", alu_out);

        // 5. SLTU (funct3 = 011, funct7 = 0000000) -> 5 < max_uint (True)
        ir   = {7'b0000000, 5'd2, 5'd1, 3'b011, 5'd3, 7'b0110011};
        in_a = 32'd5; in_b = 32'hFFFFFFFF; #10;
        if (alu_out === 32'd1) $display("[PASS] SLTU"); else $display("[FAIL] SLTU: Got %0d", alu_out);

        // 6. XOR (funct3 = 100, funct7 = 0000000)
        ir   = {7'b0000000, 5'd2, 5'd1, 3'b100, 5'd3, 7'b0110011};
        in_a = 32'h00FF00FF; in_b = 32'h0F0F0F0F; #10;
        if (alu_out === 32'h0FF00FF0) $display("[PASS] XOR"); else $display("[FAIL] XOR: Got %0h", alu_out);

        // 7. SRL (funct3 = 101, funct7 = 0000000)
        ir   = {7'b0000000, 5'd2, 5'd1, 3'b101, 5'd3, 7'b0110011};
        in_a = 32'h80000000; in_b = 32'd1; #10;
        if (alu_out === 32'h40000000) $display("[PASS] SRL"); else $display("[FAIL] SRL: Got %0h", alu_out);

        // 8. SRA (funct3 = 101, funct7 = 0100000)
        ir   = {7'b0100000, 5'd2, 5'd1, 3'b101, 5'd3, 7'b0110011};
        in_a = 32'h80000000; in_b = 32'd1; #10;
        if (alu_out === 32'hC0000000) $display("[PASS] SRA"); else $display("[FAIL] SRA: Got %0h", alu_out);

        // 9. OR (funct3 = 110, funct7 = 0000000)
        ir   = {7'b0000000, 5'd2, 5'd1, 3'b110, 5'd3, 7'b0110011};
        in_a = 32'h00F000F0; in_b = 32'h0F000F00; #10;
        if (alu_out === 32'h0FF00FF0) $display("[PASS] OR"); else $display("[FAIL] OR: Got %0h", alu_out);

        // 10. AND (funct3 = 111, funct7 = 0000000)
        ir   = {7'b0000000, 5'd2, 5'd1, 3'b111, 5'd3, 7'b0110011};
        in_a = 32'h00FF00FF; in_b = 32'h0F0F0F0F; #10;
        if (alu_out === 32'h000F000F) $display("[PASS] AND"); else $display("[FAIL] AND: Got %0h", alu_out);


        // ==========================================
        // I-TYPE ARITHMETIC INSTRUCTIONS
        // Format: {imm[11:0](12), rs1(5), funct3(3), rd(5), opcode(7)}
        // Opcode: 7'b0010011
        // ==========================================

        // 11. ADDI (funct3 = 000, imm = 15)
        ir   = {12'd15, 5'd1, 3'b000, 5'd3, 7'b0010011};
        in_a = 32'd50; in_b = 32'd15; #10;
        if (alu_out === 32'd65) $display("[PASS] ADDI"); else $display("[FAIL] ADDI: Got %0d", alu_out);

        // 12. SLTI (funct3 = 010, imm = 10) -> 5 < 10 (True)
        ir   = {12'd10, 5'd1, 3'b010, 5'd3, 7'b0010011};
        in_a = 32'd5; in_b = 32'd10; #10;
        if (alu_out === 32'd1) $display("[PASS] SLTI"); else $display("[FAIL] SLTI: Got %0d", alu_out);

        // 13. SLTIU (funct3 = 011, imm = 20)
        ir   = {12'd20, 5'd1, 3'b011, 5'd3, 7'b0010011};
        in_a = 32'd5; in_b = 32'd20; #10;
        if (alu_out === 32'd1) $display("[PASS] SLTIU"); else $display("[FAIL] SLTIU: Got %0d", alu_out);

        // 14. XORI (funct3 = 100, imm = 15)
        ir   = {12'd15, 5'd1, 3'b100, 5'd3, 7'b0010011};
        in_a = 32'h000000FF; in_b = 32'd15; #10;
        if (alu_out === 32'h000000F0) $display("[PASS] XORI"); else $display("[FAIL] XORI: Got %0h", alu_out);

        // 15. ORI (funct3 = 110, imm = 15)
        ir   = {12'd15, 5'd1, 3'b110, 5'd3, 7'b0010011};
        in_a = 32'h000000F0; in_b = 32'd15; #10;
        if (alu_out === 32'h000000FF) $display("[PASS] ORI"); else $display("[FAIL] ORI: Got %0h", alu_out);

        // 16. ANDI (funct3 = 111, imm = 15)
        ir   = {12'd15, 5'd1, 3'b111, 5'd3, 7'b0010011};
        in_a = 32'h000000FF; in_b = 32'd15; #10;
        if (alu_out === 32'h0000000F) $display("[PASS] ANDI"); else $display("[FAIL] ANDI: Got %0h", alu_out);

        // 17. SLLI (funct3 = 001, imm[4:0] = 3)
        ir   = {12'd3, 5'd1, 3'b001, 5'd3, 7'b0010011};
        in_a = 32'd2; in_b = 32'd3; #10;
        if (alu_out === 32'd16) $display("[PASS] SLLI"); else $display("[FAIL] SLLI: Got %0d", alu_out);

        // 18. SRLI (funct3 = 101, imm[11:5] = 0000000, imm[4:0] = 1)
        ir   = {7'b0000000, 5'd1, 5'd1, 3'b101, 5'd3, 7'b0010011};
        in_a = 32'h80000000; in_b = 32'd1; #10;
        if (alu_out === 32'h40000000) $display("[PASS] SRLI"); else $display("[FAIL] SRLI: Got %0h", alu_out);

        // 19. SRAI (funct3 = 101, imm[11:5] = 0100000, imm[4:0] = 1)
        ir   = {7'b0100000, 5'd1, 5'd1, 3'b101, 5'd3, 7'b0010011};
        in_a = 32'h80000000; in_b = 32'd1; #10;
        if (alu_out === 32'hC0000000) $display("[PASS] SRAI"); else $display("[FAIL] SRAI: Got %0h", alu_out);

        // 20. Custom Test: add x6, x1, x3 (add values from reg 1 and reg 3, store in reg 6)
        // ir = {funct7(7), rs2(5), rs1(5), funct3(3), rd(5), opcode(7)}
        // funct7 = 0000000, rs2 = 3 (00011), rs1 = 1 (00001), funct3 = 000, rd = 6 (00110), opcode = 0110011
        ir   = 32'h00308333;
        in_a = 32'd2; // simulating value from reg 1
        in_b = 32'd7; // simulating value from reg 3
        #10;
        if (alu_out === 32'd9) 
            $display("[PASS] Custom ADD x6, x1, x3: 2 + 7 = %0d", alu_out);
        else 
            $display("[FAIL] Custom ADD x6, x1, x3: Expected 9, Got %0d", alu_out);
        
        $display("=== ALL INSTRUCTION TESTS COMPLETED ===");
        $finish;
    end

endmodule
`timescale 1ns / 1ps

module sign_ext(ir, sext_out);

input [31:0] ir;
output reg [31:0] sext_out;

// Extract opcode and funct3 for internal self-decoding
wire [6:0] opcode = ir[6:0];

localparam IMM_I  = 3'b000;
localparam IMM_S  = 3'b001;
localparam IMM_B  = 3'b010;
localparam IMM_U  = 3'b011;
localparam IMM_J  = 3'b100;

reg [2:0] imm_type_ctr;

// Self-decode immediate type based on RISC-V opcode structure
always @(*) begin
    casex (opcode)
        7'b0010011, // I-Type Arith (addi, slti, etc.)
        7'b0000011, // Loads (lw, lb, etc.)
        7'b1100111: imm_type_ctr = IMM_I; // JALR

        7'b0100011: imm_type_ctr = IMM_S; // S-Type (Stores)
        7'b1100011: imm_type_ctr = IMM_B; // B-Type (Branches)
        
        7'b0110111, 
        7'b0010111: imm_type_ctr = IMM_U; // U-Type (LUI, AUIPC)
        
        7'b1101111: imm_type_ctr = IMM_J; // J-Type (JAL)
        
        default:    imm_type_ctr = IMM_I;
    endcase
end

// Immediate generation logic
always @(*) begin
    case(imm_type_ctr)
        // I-Type: 12-bit immediate (ir[31:20])
        IMM_I: begin
            sext_out = {{20{ir[31]}}, ir[31:20]};
        end
        // S-Type: 12-bit immediate split across ir[31:25] and ir[11:7]
        IMM_S: begin
            sext_out = {{20{ir[31]}}, ir[31:25], ir[11:7]};
        end
        // B-Type: 13-bit branch offset (1-bit left-shifted, LSB is 0)
        IMM_B: begin
            sext_out = {{19{ir[31]}}, ir[31], ir[7], ir[30:25], ir[11:8], 1'b0};
        end
        // U-Type: 20-bit upper immediate (placed in upper 20 bits, 12 LSBs zeroed)
        IMM_U: begin
            sext_out = {ir[31:12], 12'b0};
        end
        // J-Type: 21-bit jump target offset (1-bit left-shifted, LSB is 0)
        IMM_J: begin
            sext_out = {{11{ir[31]}}, ir[31], ir[19:12], ir[20], ir[30:21], 1'b0};
        end
        default: begin
            sext_out = 32'h0000_0000;
        end
    endcase
end

endmodule
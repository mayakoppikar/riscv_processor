`timescale 1ns / 1ps

module alu(in_a, in_b, ir, alu_op, alu_out, N, Z, C, V);

input [31:0] in_a, in_b;
input [31:0] ir;
input [1:0] alu_op;
output reg [31:0] alu_out;
output N, Z, C, V;

wire [2:0] funct3   = ir[14:12];
wire [6:0] opcode   = ir[6:0];
wire       funct7_5 = ir[30];   // distinguishes ADD/SUB and SRL/SRA

wire is_r_type  = (opcode == 7'b0110011);
wire is_i_arith = (opcode == 7'b0010011);
wire is_branch  = (opcode == 7'b1100011);
// Only R-type / I-type arithmetic use funct3 to pick the ALU function.
// Loads, stores, JALR, AUIPC etc. reuse funct3 for other meanings (e.g. lw = 010 = slt),
// so they must NOT be decoded as slt/sltu/shift/logic.
wire is_alu     = is_r_type | is_i_arith;

// --- ADDER CONTROLS ---
wire is_slt  = is_alu && (funct3 == 3'b010);   // SLT / SLTI
wire is_sltu = is_alu && (funct3 == 3'b011);   // SLTU / SLTIU
// Subtract for: R-type SUB, SLT/SLTU, and branches (compare via subtraction)
wire is_sub  = (is_r_type && (funct3 == 3'b000) && funct7_5) ||
               is_slt || is_sltu || is_branch;

// --- SHIFT CONTROLS ---
wire is_sll = is_alu && (funct3 == 3'b001);
wire is_srl = is_alu && (funct3 == 3'b101) && !funct7_5;
wire is_sra = is_alu && (funct3 == 3'b101) &&  funct7_5;

// --- LOGIC CONTROLS --- 2'b00 = AND, 2'b01 = OR, 2'b10 = XOR
wire [1:0] logic_sel = (funct3 == 3'b111) ? 2'b00 :
                       (funct3 == 3'b110) ? 2'b01 :
                       (funct3 == 3'b100) ? 2'b10 : 2'b00;

localparam ADDERS   = 2'b00;
localparam SHIFTERS = 2'b01;
localparam LOGICS   = 2'b10;
localparam PASSTHRU = 2'b11;

// --- ADDER / SUBTRACTOR ---
// Subtraction = A + ~B + 1, using a carry-in (avoids the overflow bug when B == 0)
wire [31:0] opb       = is_sub ? ~in_b : in_b;
wire [32:0] adder_ext = {1'b0, in_a} + {1'b0, opb} + {32'd0, is_sub};
wire [31:0] adder_out = adder_ext[31:0];

assign N = adder_out[31];
assign Z = (adder_out == 32'd0);
assign C = adder_ext[32];   // for subtraction: C = 1 means no borrow (A >= B unsigned)
assign V = (in_a[31] == opb[31]) && (adder_out[31] != in_a[31]);

wire [31:0] slt_out  = {31'b0, N ^ V};   // signed less-than
wire [31:0] sltu_out = {31'b0, ~C};      // unsigned less-than (borrow)

wire [31:0] into_alu_adder = is_slt  ? slt_out  :
                             is_sltu ? sltu_out : adder_out;

// --- SHIFTER ---
wire [4:0]  shamt = in_b[4:0];
wire [31:0] sll_out = in_a << shamt;
wire [31:0] srl_out = in_a >> shamt;
wire [31:0] sra_out = $signed(in_a) >>> shamt;

wire [31:0] into_alu_shifter = is_sll ? sll_out :
                               is_srl ? srl_out :
                               is_sra ? sra_out : 32'd0;

// --- LOGIC ---
wire [31:0] into_alu_logic = (logic_sel == 2'b00) ? (in_a & in_b) :
                             (logic_sel == 2'b01) ? (in_a | in_b) :
                                                    (in_a ^ in_b);

// --- OUTPUT MUX ---
always @(*) begin
    case (alu_op)
        ADDERS:   alu_out = into_alu_adder;
        SHIFTERS: alu_out = into_alu_shifter;
        LOGICS:   alu_out = into_alu_logic;
        PASSTHRU: alu_out = in_a;
        default:  alu_out = 32'd0;
    endcase
end

endmodule

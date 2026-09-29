`timescale 1ns / 1ps

module alu(in_a, in_b, ir, alu_out, N, Z, C, V);

input [31:0] in_a, in_b;
input [31:0] ir;
reg [1:0] alu_op;
output reg [31:0] alu_out;
output N, Z, C, V;

//control signals for adders
wire is_slt, is_sub, is_sltu;
//control signals for shifters
wire is_sll, is_srl, is_sra;
//control signals for logic
wire [1:0] logic_sel;

wire [2:0] funct3    = ir[14:12];
wire       funct7_5  = ir[30];          // Bit 30 distinguishes ADD/SUB and SRL/SRA
wire       is_r_type = (ir[6:0] == 7'b0110011);
wire       is_i_arith= (ir[6:0] == 7'b0010011);

// --- SUBTRACTION & COMPARISON CONTROLS ---
// is_sub is active for: R-type SUB, plus SLT and SLTU (which use subtraction internally)
assign is_sub = (is_r_type && (funct3 == 3'b000) && funct7_5) || // R-type SUB
                (funct3 == 3'b010) ||                           // SLT / SLTI
                (funct3 == 3'b011);                           // SLTU / SLTIU

assign is_slt  = (funct3 == 3'b010); // SLT / SLTI
assign is_sltu = (funct3 == 3'b011); // SLTU / SLTIU


// --- SHIFT CONTROLS ---
assign is_sll = (funct3 == 3'b001);                 // SLL / SLLI
assign is_srl = (funct3 == 3'b101) && !funct7_5;    // SRL / SRLI
assign is_sra = (funct3 == 3'b101) &&  funct7_5;    // SRA / SRAI


wire [1:0] logic_sel;

// Encode: 2'b00 = AND, 2'b01 = OR, 2'b10 = XOR
assign logic_sel = (funct3 == 3'b111) ? 2'b00 : // AND / ANDI
                   (funct3 == 3'b110) ? 2'b01 : // OR / ORI
                   (funct3 == 3'b100) ? 2'b10 : // XOR / XORI
                   2'b00;


// --- ALU_OP GROUPING ---
// 2'b00: Adder-based (Add, Sub, SLT, SLTU, ADDI, etc.)
// 2'b01: Shifters (SLL, SRL, SRA)
// 2'b10: Logic operations (AND, OR, XOR)
// 2'b11: Pass A (or default)
always @(*) begin
    case (funct3)
        3'b000, 
        3'b010, 
        3'b011: alu_op = 2'b00; // Adder / Comparators
        
        3'b001, 
        3'b101: alu_op = 2'b01; // Shifters
        
        3'b100, 
        3'b110, 
        3'b111: alu_op = 2'b10; // Logic (AND, OR, XOR)
        
        default: alu_op = 2'b00;
    endcase
end



localparam ADDERS  = 2'b00;
localparam SHIFTERS  = 2'b01;
localparam LOGICS  = 2'b10;
localparam PASSTHRU  = 2'b11;

wire [31:0] into_alu_adder, into_alu_shifter, into_alu_logic;

//adder comb logic
wire [31:0] inp_adder, adder_out, inp_slt, inp_sltu, slt_out;
assign inp_adder = (is_sub | is_slt | is_sltu) ? (~in_b + 32'd1) : in_b;
wire [32:0] adder_ext = {1'b0, in_a} + {1'b0, inp_adder};
assign adder_out = adder_ext[31:0];
assign slt_out = is_slt ? inp_slt : inp_sltu;
assign into_alu_adder = (is_slt | is_sltu) ? slt_out : adder_out;

assign N = adder_out[31];
assign Z = (adder_out == 32'd0);
assign C = adder_ext[32];
assign V = (in_a[31] == inp_adder[31]) ? ((in_a[31] != adder_out[31]) ? 1'b1 : 1'b0) : 1'b0;

assign inp_slt  = {31'b0, N ^ V};
assign inp_sltu = {31'b0, ~C};

//shifting logic
wire [4:0] shamt = in_b[4:0];
wire [31:0] sll_out = in_a << shamt;
wire [31:0] srl_out = in_a >> shamt;
wire [31:0] sra_out = $signed(in_a) >>> shamt;

assign into_alu_shifter = is_sll ? sll_out :
                          is_srl ? srl_out :
                          is_sra ? sra_out : 32'd0;
                          
                          
//Logic logic lol
assign into_alu_logic =
    (logic_sel == 2'b00) ? (in_a & in_b) :
    (logic_sel == 2'b01) ? (in_a | in_b) :
    (logic_sel == 2'b10) ? (in_a ^ in_b) : 32'd0;

always @(*)begin
    case(alu_op)
        ADDERS: begin
          alu_out = into_alu_adder;      
        end
        SHIFTERS: begin
          alu_out = into_alu_shifter;
        end
        LOGICS: begin
            alu_out = into_alu_logic;
        end
        PASSTHRU: begin
            alu_out = in_a;
        end       
    endcase
end

endmodule

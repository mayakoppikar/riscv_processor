`timescale 1ns / 1ps

module multi_cycle_riscv(clk, rst);
//inputs and outputs
input clk, rst;

//registers
reg [31:0] pc, ir, old_pc, mar, mdr;
wire n, z, c, v; // Fixed: changed from reg to wire (driven by ALU output ports)
reg [1:0] alu_op;
wire [2:0] funct3    = ir[14:12];


//state machine
reg [3:0] state, nstate;
wire [31:0] bus;

parameter [3:0] 
        fetch_1= 4'd0,
        fetch_2= 4'd1,
        fetch_3= 4'd2,
        decode = 4'd3,
        a_exec = 4'd4,
        b_exec = 4'd5,
        b_mem = 4'd6,
        b_wb = 4'd7,
        c_exec = 4'd8,
        c_mem = 4'd9,
        d_exec = 4'd10,
        d_target = 4'd11, //this si if branch is taken state
        e_exec = 4'd12,
        f_exec = 4'd13;
    
        
//control signals
//muxes
reg sr1_or_oldPc;
wire [31:0] mem_in;
reg choose_sr2, bus_or_mdr;
reg addr_mux_crtl; // 0 = 32'd0, 1 = sext_out
reg [1:0] pc_mux_ctrl;
reg ir_or_bus; //for sign extend unit input
reg sext_or_bus; //input to reg file either sext_out or bus 
//bus gates
reg GateALU, GateMDR, GatePc, GateAddr;
//load controls
reg ld_mar, ld_mdr, ld_old_pc, ld_ir, ld_pc, ld_reg;
//memory
reg [1:0] mem_size_sel; // Fixed: changed to 2-bit width to match memory port
reg mem_signed, mem_cs, mem_we;

//wires and intermediate signals
wire [31:0] alu_in_a, alu_in_b, sr1_out, sr2_out, alu_out; // Fixed: added sr2_out
wire [31:0] sext_out;
wire [31:0] pc_in, alu_inv, addr_out;
wire [31:0] mdr_in, mem_out;
wire [31:0] sext_in, reg_file_in;

// Extract opcode from instruction register
wire [6:0] opcode = ir[6:0];
wire [1:0] mar_shf_amt = ir[13:12]; //2'b00 = byte, 2'b01 = halfword 2'b11 = word
wire [31:0] into_alu_a;
assign into_alu_a = sr1_or_oldPc ? old_pc : alu_in_a;

// Track Routing Conditions
wire is_track_a = (opcode == 7'b0110011) || (opcode == 7'b0010011); // R-type or I-type Arith
wire is_track_b = (opcode == 7'b0000011);                           // Loads
wire is_track_c = (opcode == 7'b0100011);                           // Stores
wire is_track_d = (opcode == 7'b1100011);                           // Branches
wire is_track_e = (opcode == 7'b1101111) ||                         // jal
                  (opcode == 7'b1100111);                           // jalr
wire is_track_f = (opcode == 7'b0110111) ||                         // lui
                  (opcode == 7'b0010111);                           // auipc

//initalize modules (reg file, m6emory, sign_ext, alu)
sign_ext sign_ext_multi(.ir(sext_in), .from_bus(ir_or_bus), .isSigned(ir[14]), .data_size(funct3[1:0]), .sext_out(sext_out));
alu alu_multi(.in_a(into_alu_a), .in_b(alu_in_b), .ir(ir), .alu_op(alu_op),
              .br_cmp(state == d_exec),
              .alu_out(alu_out), .N(n), .Z(z), .C(c), .V(v));
              
reg_file rf_multi(.clk(clk), .ld_reg(ld_reg), .sr1(ir[19:15]), .sr2(ir[24:20]), .bus_in(reg_file_in), .dr(ir[11:7]), .sr1_out(alu_in_a), .sr2_out(sr2_out));
memory #(
        .ADDR_WIDTH(12) 
    ) mem_multi (
        .clk(clk),
        .cs(mem_cs),          
        .we(mem_we),          
        .size_sel(mem_size_sel),  
        .mar_addr(mar),  
        .din(mem_in),
        .dout(mem_out)        
    );

//combinational logic
assign mem_in = bus_or_mdr ? bus : mdr;
assign reg_file_in = sext_or_bus ? sext_out : bus;
assign sext_in = ir_or_bus ? bus : ir;
assign alu_in_b = choose_sr2 ? sext_out : sr2_out;
assign pc_in = (pc_mux_ctrl == 2'b00) ? bus :
               (pc_mux_ctrl == 2'b01) ? alu_inv : 
               (pc_mux_ctrl == 2'b10) ? addr_out : 
               (pc + 32'd4);
assign addr_out = addr_mux_crtl ? sext_out : 32'd0;

assign bus = GateALU  ? alu_out :
             GateMDR  ? mdr     : //come back later to sypport singed nums
             GatePc   ? pc      :
             GateAddr ? addr_out     : 
                        32'h00000000; 

always @(*) begin
    nstate = state;
    ld_mar = 1'b0; ld_mdr = 1'b0; ld_old_pc = 1'b0; ld_ir = 1'b0; ld_pc = 1'b0; ld_reg = 1'b0;
    GateALU = 1'b0; GateMDR = 1'b0; GatePc = 1'b0; GateAddr = 1'b0;
    pc_mux_ctrl = 2'b00; bus_or_mdr = 1'b0;
    mem_size_sel = 2'b00; mem_signed = 1'b0; mem_cs= 1'b0; mem_we = 1'b0;
    choose_sr2 = (opcode == 7'b0010011) ? 1'b1 : 1'b0;
    ir_or_bus = 1'b0; sext_or_bus = 1'b0;
    addr_mux_crtl = 1'b0; 
    sr1_or_oldPc = 1'b0;
    
    case (state)
        fetch_1: begin
            ld_mar = 1'b1;
            ld_pc = 1'b1;
            ld_old_pc = 1'b1;
            GatePc = 1'b1;
            pc_mux_ctrl = 2'b11;
            nstate = fetch_2;
        end
        fetch_2: begin
            mem_cs = 1'b1;
            mem_size_sel = 2'b11;
            ld_mdr = 1'b1;  
            nstate = fetch_3;
        end
        fetch_3: begin
            ld_ir = 1'b1; 
            GateMDR = 1'b1;
            nstate = decode;
        end
        decode: begin
           if (is_track_a)       nstate = a_exec;
           else if (is_track_b)  nstate = b_exec;
           else if (is_track_c)  nstate = c_exec;
           else if (is_track_d)  nstate = d_exec;
           else if (is_track_e)  nstate = e_exec;
           else if( is_track_f) nstate = f_exec;
           else                  nstate = fetch_1; 
        end
        a_exec: begin
            GateALU = 1'b1;
            ld_reg = 1'b1;
            nstate = fetch_1;
        end
        b_exec: begin
            GateALU = 1'b1;
            choose_sr2 = 1'b1;
            ld_mar = 1'b1;
            nstate = b_mem;
        end
        b_mem: begin
            mem_cs = 1'b1;
            mem_size_sel = funct3[1:0];
            ld_mdr = 1'b1;  
            nstate = b_wb;
        end
        b_wb: begin 
           ir_or_bus = 1'b1;
           GateMDR = 1'b1;
           sext_or_bus = 1'b1;
           ld_reg = 1'b1;
           nstate = fetch_1;
        end
        c_exec: begin
            GateALU = 1'b1;
            choose_sr2 = 1'b1;
            ld_mar = 1'b1;
            nstate = c_mem;
        end
        c_mem: begin
            GateALU = 1'b1;
            bus_or_mdr = 1'b1;
            mem_cs = 1'b1;
            mem_size_sel = funct3[1:0];
            mem_we = 1'b1;   
            nstate = fetch_1;
        end
        d_exec: begin //subtract sr1 - sr2
            //control bits are set outside
            nstate = fetch_1;
            case (funct3)
                3'b000: begin //beq
                    if(z == 1'b1) nstate = d_target;
                end
                3'b001: begin //bne
                    if(z == 1'b0) nstate = d_target;
                end
                3'b100: begin //blt
                    if((n ^ v) == 1'b1) nstate = d_target;
                end
                3'b101: begin //bge
                    if((n ^ v) == 1'b0) nstate = d_target;
                end
                3'b110: begin //bltu
                    if(c == 1'b0) nstate = d_target;
                end
                3'b111: begin //bgeu
                     if(c == 1'b1) nstate = d_target;
                end
            endcase
        end
        d_target: begin
           sr1_or_oldPc = 1'b1;
           choose_sr2 = 1'b1;
           GateALU = 1'b1; 
           ld_pc = 1'b1;
           nstate = fetch_1;
        end
        e_exec: begin
            
        end
        f_exec: begin
            
        end
        default: nstate = fetch_1;
    endcase
end

always @(posedge clk or posedge rst)begin
    state <= nstate;
    if (rst) begin
        state <= fetch_1;
        pc  <= 32'h00000000;
        ir  <= 32'h00000000;
        mar <= 32'h00000000;
        mdr <= 32'h00000000;
        old_pc <= 32'h00000000;
    end else begin
        if (ld_pc)  pc  <= pc_in;
        if (ld_ir)  ir  <= bus;
        if (ld_mar) mar <= bus;
        if (ld_mdr) mdr <= mem_out;
        if (ld_old_pc) old_pc <= bus;
    end
end

// --- ALU_OP GROUPING ---
// 2'b00: Adder-based (Add, Sub, SLT, SLTU, ADDI, etc.)
// 2'b01: Shifters (SLL, SRL, SRA)
// 2'b10: Logic operations (AND, OR, XOR)
// 2'b11: Pass A (or default)
always @(*) begin
if((state == b_exec) || (state == c_exec) || (state == d_exec) || (state == d_target)) alu_op = 2'b00;
else if(state == c_mem) alu_op = 2'b11;
else begin
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
end

endmodule
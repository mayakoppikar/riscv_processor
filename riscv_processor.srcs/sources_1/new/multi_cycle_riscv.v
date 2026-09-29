`timescale 1ns / 1ps

module multi_cycle_riscv(clk, rst);
//inputs and outputs
input clk, rst;

//registers
reg [31:0] pc, ir, old_pc, mar, mdr;
wire n, z, c, v; // Fixed: changed from reg to wire (driven by ALU output ports)

//state machine
reg [6:0] state, nstate;
wire [31:0] bus;

parameter [5:0] 
        fetch_1= 6'd0,
        fetch_2= 6'd1,
        fetch_3= 6'd2,
        decode = 6'd3,
        a_exec = 6'd4,
        b_exec = 6'd5,
        c_exec = 6'd6,
        d_exec = 6'd7,
        e_exec = 6'd8;
    
//control signals
//muxes
reg choose_sr2, mdr_sel;
reg [1:0] addr_mux_crtl; // add sext/oldpc/0 for LUI
reg [1:0] pc_mux_ctrl;
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

// Extract opcode from instruction register
wire [6:0] opcode = ir[6:0];

// Track Routing Conditions
wire is_track_a = (opcode == 7'b0110011) || (opcode == 7'b0010011); // R-type or I-type Arith
wire is_track_b = (opcode == 7'b0000011);                           // Loads
wire is_track_c = (opcode == 7'b0100011);                           // Stores
wire is_track_d = (opcode == 7'b1100011);                           // Branches
wire is_track_e = (opcode == 7'b0110111) ||                         // lui
                  (opcode == 7'b0010111) ||                         // auipc
                  (opcode == 7'b1101111) ||                         // jal
                  (opcode == 7'b1100111);                           // jalr

//initalize modules (reg file, memory, sign_ext, alu)
sign_ext sign_ext_multi(.ir(ir), .sext_out(sext_out));
alu alu_multi(.in_a(alu_in_a), .in_b(alu_in_b), .ir(ir), .alu_out(alu_out), .N(n), .Z(z), .C(c), .V(v));
reg_file rf_multi(.clk(clk), .rst(rst), .ld_reg(ld_reg), .sr1(ir[19:15]), .sr2(ir[24:20]), .bus_in(bus), .dr(ir[11:7]), .sr1_out(alu_in_a), .sr2_out(sr2_out));
memory #(
        .ADDR_WIDTH(12) 
    ) mem_multi (
        .clk(clk),
        .cs(mem_cs),          
        .we(mem_we),          
        .size_sel(mem_size_sel),  
        .mar_addr(mar),  
        .din(mdr),
        .dout(mem_out)        
    );

//combinational logic
assign alu_in_b = choose_sr2 ? sext_out : sr2_out;
assign pc_in = (pc_mux_ctrl == 2'b00) ? bus :
               (pc_mux_ctrl == 2'b01) ? alu_inv : 
               (pc_mux_ctrl == 2'b10) ? addr_out : 
               (pc + 32'd4);
assign mdr_in = mdr_sel ? bus : mem_out;
assign addr_out = (addr_mux_crtl == 2'b00) ? 32'h00000000 : (addr_mux_crtl == 2'b01) ? sext_out : old_pc;

assign bus = GateALU  ? alu_out :
             GateMDR  ? mdr     : //come back later to sypport singed nums
             GatePc   ? pc      :
             GateAddr ? addr_out     : 
                        32'h00000000; 

always @(*) begin
    nstate = state;
    ld_mar = 1'b0; ld_mdr = 1'b0; ld_old_pc = 1'b0; ld_ir = 1'b0; ld_pc = 1'b0; ld_reg = 1'b0;
    GateALU = 1'b0; GateMDR = 1'b0; GatePc = 1'b0; GateAddr = 1'b0;
    pc_mux_ctrl = 2'b00; mdr_sel = 1'b0;
    mem_size_sel = 2'b00; mem_signed = 1'b0; mem_cs= 1'b0; mem_we = 1'b0;
    choose_sr2 = (opcode == 7'b0010011) ? 1'b1 : 1'b0;
    
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
           else                  nstate = fetch_1; 
        end
        a_exec: begin
            GateALU = 1'b1;
            ld_reg = 1'b1;
            nstate = fetch_1;
        end
        b_exec: begin
            
        end
        c_exec: begin
            
        end
        d_exec: begin
            
        end
        e_exec: begin
            
        end
        default: nstate = fetch_1;
    endcase
end

always @(posedge clk or posedge rst)begin
    state <= nstate;
    if (rst) begin
        pc  <= 32'h00000000;
        ir  <= 32'h00000000;
        mar <= 32'h00000000;
        mdr <= 32'h00000000;
        old_pc <= 32'h00000000;
    end else begin
        if (ld_pc)  pc  <= pc_in;
        if (ld_ir)  ir  <= bus;
        if (ld_mar) mar <= bus;
        if (ld_mdr) mdr <= mdr_in;
        if (ld_old_pc) old_pc <= bus;
    end
end

endmodule
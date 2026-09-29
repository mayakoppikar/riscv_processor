`timescale 1ns / 1ps

module reg_file(clk, rst, ld_reg, sr1, sr2, bus_in, dr, sr1_out, sr2_out);
    
  input clk, rst, ld_reg;
  input [4:0] sr1, sr2, dr;
  input [31:0] bus_in;
  output [31:0] sr1_out, sr2_out;    
  
  reg [31:0] REG [31:0]; //32x32
  
  assign sr1_out = (sr1 == 5'b00000) ? 32'd0 : REG[sr1];
  assign sr2_out = (sr2 == 5'b00000) ? 32'd0 : REG[sr2];
  
  integer i;

  // Initial block to set all registers to 0 at time 0
  initial begin
      for(i = 0; i < 32; i = i + 1) begin
          REG[i] = 32'd0;
      end
  end
  
  always @(posedge clk or posedge rst) begin
    if(rst) begin
        for(i=0; i < 32; i=i+1) begin
            REG[i] = 32'd0;
        end
    end
    else if(ld_reg && (dr != 5'b00000))begin
        REG[dr] <= bus_in;
    end
  end
    
endmodule
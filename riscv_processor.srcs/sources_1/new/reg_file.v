module reg_file(clk, rst, ld_reg, sr1, sr2, bus_in, dr, sr1_out, sr2_out);
  input clk, rst, ld_reg;
  input [4:0] sr1, sr2, dr;
  input [31:0] bus_in;
  output [31:0] sr1_out, sr2_out;

  reg [31:0] REG [31:1];   //no x0 anymore

  assign sr1_out = (sr1 == 5'd0) ? 32'd0 : REG[sr1];
  assign sr2_out = (sr2 == 5'd0) ? 32'd0 : REG[sr2];

  integer i;
  always @(posedge clk) begin
    if (rst) begin //synch reset
      for (i = 1; i < 32; i = i + 1)
        REG[i] <= 32'd0;
    end else if (ld_reg && (dr != 5'd0)) begin
      REG[dr] <= bus_in;
    end
  end
endmodule
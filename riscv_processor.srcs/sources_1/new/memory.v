`timescale 1ns / 1ps

module memory #(
    parameter ADDR_WIDTH = 12 // 12 bits = 4096 bytes (4 KB of byte-addressable memory)
)(
    input wire clk,
    input wire cs,              
    input wire we,              // 0 = read, 1 = write
    input wire [1:0] size_sel,  // 2'b00 = Byte, 2'b01 = Halfword, 2'b10/2'b11 = Word
    input wire [31:0] mar_addr, 
    input wire [31:0] din,      
    output reg [31:0] dout     
);

  integer i;
    // True byte-addressable memory array: each location holds 1 Byte (8 bits)
    reg [7:0] MEM [0:(1 << ADDR_WIDTH)-1];
    
  initial
  begin
    /* Write your Verilog-Text IO code here */
   for (i= 0; i < 128; i=i+1) begin
        MEM[i] = 32'd0;
    end
     $readmemh("simple_addition.mem", MEM);
     $display("[Memory] Loaded simple_addition.mem successfully.");
       
  end

    integer i;
    initial begin
        // Clear memory to 0 to avoid 'x' unknowns if hex file is missing
        for (i = 0; i < (1 << ADDR_WIDTH); i = i + 1) begin
            MEM[i] = 8'h00;
        end
//        $readmemh("program.hex", MEM);
    end

    //  Read (Little-Endian)
    always @(*) begin
        if (cs && !we) begin
            dout = {MEM[mar_addr + 3], MEM[mar_addr + 2], MEM[mar_addr + 1], MEM[mar_addr]};
        end else begin
            dout = 32'd0;
        end
    end

    always @(posedge clk) begin
        if (cs && we) begin
            case (size_sel)
                2'b00: begin // Store Byte (sb)
                    MEM[mar_addr] <= din[7:0];
                end
                2'b01: begin // Store Halfword (sh)
                    MEM[mar_addr]     <= din[7:0];
                    MEM[mar_addr + 1] <= din[15:8];
                end
                2'b10, 2'b11: begin // Store Word (sw)
                    MEM[mar_addr]     <= din[7:0];
                    MEM[mar_addr + 1] <= din[15:8];
                    MEM[mar_addr + 2] <= din[23:16];
                    MEM[mar_addr + 3] <= din[31:24];
                end
                default: begin
                    MEM[mar_addr]     <= din[7:0];
                    MEM[mar_addr + 1] <= din[15:8];
                    MEM[mar_addr + 2] <= din[23:16];
                    MEM[mar_addr + 3] <= din[31:24];
                end
            endcase
        end
    end

endmodule
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/13/2025 05:00:39 PM
// Design Name: 
// Module Name: Lab2Dataflow
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module FSMdataflow(X, CLK, S, V);
input X, CLK;
output S, V;

reg A;
reg B;
reg C;

initial begin 
    A = 0;
    B = 0;
    C = 0;
    //#25;
end

always @(posedge CLK)
begin
   A <=((A & (~B) & C) | ((~A) & (B) & C) | ((~X) & (~A) & B));
   B <=(((~X) & (~A) & (~B)) | (X & (~A) & C) | (X & (~A) & B));
   C <=((X & (~A)) | (B & (~C)) | ((~A) & (~B) & C));
end
assign S =(((~X)& B) | ((~X) & (~A) & (~C)) | (X & A & (~B)) | (X & (~B) & C));
assign V =(X & A & B);
endmodule
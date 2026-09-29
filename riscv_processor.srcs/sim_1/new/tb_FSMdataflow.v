`timescale 1ns / 1ps

module tb_FSMdataflow;
    reg X;
    reg CLK;
    wire S;
    wire V;
    

    FSMdataflow uut (
        .X(X),
        .CLK(CLK),
        .S(S),
        .V(V)
    );

    initial begin
        // Initialize signals
        CLK = 0;
        X = 0;
  
        
        #4 X = 1; #10 X = 0; #10 X = 1; #10 X = 1; // 1011
        #10 X = 1; #10 X = 1; #10 X = 0; #10 X = 0; // 1100
        #10 X = 1; #10 X = 1; #10 X = 0; #10 X = 1; // 1101
        
        #10 $stop;
    end

    always begin
        #5 CLK = ~CLK; // Clock period  10ns
    end

endmodule

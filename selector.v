`timescale 1ns / 1ps

module selector(
    input [15:0] N,
    input [3:0] sel,
    output [3:0] H
);

    wire sel0, sel1, sel2, sel3;
    
    assign sel0 = ~sel[3] & ~sel[2] & ~sel[1] & sel[0];
    assign sel1 = ~sel[3] & ~sel[2] & sel[1] & ~sel[0];
    assign sel2 = ~sel[3] & sel[2] & ~sel[1] & ~sel[0];
    assign sel3 = sel[3] & ~sel[2] & ~sel[1] & ~sel[0];
    
    assign H[0] = (sel0 & N[0]) | (sel1 & N[4]) | (sel2 & N[8]) | (sel3 & N[12]);
    assign H[1] = (sel0 & N[1]) | (sel1 & N[5]) | (sel2 & N[9]) | (sel3 & N[13]);
    assign H[2] = (sel0 & N[2]) | (sel1 & N[6]) | (sel2 & N[10]) | (sel3 & N[14]);
    assign H[3] = (sel0 & N[3]) | (sel1 & N[7]) | (sel2 & N[11]) | (sel3 & N[15]);

endmodule

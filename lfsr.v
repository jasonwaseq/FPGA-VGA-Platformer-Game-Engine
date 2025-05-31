`timescale 1ns / 1ps

module lfsr(
    input clk_i,
    input reset_i,
    output [7:0] q_o
    );
    
    wire feedback;
    wire[7:0] d;
    
    assign feedback = q_o[0] ^ q_o[5] ^ q_o[6] ^ q_o[7];
    
    assign d[7] = feedback;
    assign d[6] = q_o[7];
    assign d[5] = q_o[6];
    assign d[4] = q_o[5];
    assign d[3] = q_o[4];
    assign d[2] = q_o[3];
    assign d[1] = q_o[2];
    assign d[0] = q_o[1];
    
    FDRE #(.INIT(1'b1)) ff7 (.C(clk_i), .CE(1'b1), .R(reset_i), .D(d[7]), .Q(q_o[7]));
    FDRE #(.INIT(1'b0)) ff6 (.C(clk_i), .CE(1'b1), .R(reset_i), .D(d[6]), .Q(q_o[6]));
    FDRE #(.INIT(1'b0)) ff5 (.C(clk_i), .CE(1'b1), .R(reset_i), .D(d[5]), .Q(q_o[5]));
    FDRE #(.INIT(1'b0)) ff4 (.C(clk_i), .CE(1'b1), .R(reset_i), .D(d[4]), .Q(q_o[4]));
    FDRE #(.INIT(1'b0)) ff3 (.C(clk_i), .CE(1'b1), .R(reset_i), .D(d[3]), .Q(q_o[3]));
    FDRE #(.INIT(1'b0)) ff2 (.C(clk_i), .CE(1'b1), .R(reset_i), .D(d[2]), .Q(q_o[2]));
    FDRE #(.INIT(1'b0)) ff1 (.C(clk_i), .CE(1'b1), .R(reset_i), .D(d[1]), .Q(q_o[1]));
    FDRE #(.INIT(1'b0)) ff0 (.C(clk_i), .CE(1'b1), .R(reset_i), .D(d[0]), .Q(q_o[0]));
    
endmodule

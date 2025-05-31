`timescale 1ns / 1ps

module ring_counter(
    input advance_i,
    input clk_i,
    output [3:0] data_o
);

    wire [3:0] d, q;
    
    assign d[0] = (advance_i & q[1]) | (~advance_i & q[0]);
    assign d[1] = (advance_i & q[2]) | (~advance_i & q[1]);
    assign d[2] = (advance_i & q[3]) | (~advance_i & q[2]);
    assign d[3] = (advance_i & q[0]) | (~advance_i & q[3]);
    
    FDRE #(.INIT(1'b1)) ff0 (.C(clk_i), .R(1'b0), .CE(1'b1), .D(d[0]), .Q(q[0]));
    FDRE #(.INIT(1'b0)) ff1 (.C(clk_i), .R(1'b0), .CE(1'b1), .D(d[1]), .Q(q[1]));
    FDRE #(.INIT(1'b0)) ff2 (.C(clk_i), .R(1'b0), .CE(1'b1), .D(d[2]), .Q(q[2]));
    FDRE #(.INIT(1'b0)) ff3 (.C(clk_i), .R(1'b0), .CE(1'b1), .D(d[3]), .Q(q[3]));
    
    assign data_o = q;

endmodule

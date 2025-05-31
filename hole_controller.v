`timescale 1ns / 1ps

module hole_controller (
  input  wire         clk_i,         // Clock input
  input  wire         reset_i,       // Synchronous reset
  input  wire         frame_tick,    // Signal to advance frame (e.g., pixel/frame clock)
  input  wire         go_i,          // Start/restart movement signal
  input  wire [7:0]   random_num,    // Random number input to determine hole width

  output wire [9:0]   hole_x,        // X position of the hole
  output wire [6:0]   hole_w,        // Width of the hole
  output wire         hole_off_left, // High when the hole is off the left edge of the screen
  output wire [9:0]   hole_end       // Right edge of the hole
);

  // Normalize random_num to a range of 0-30 (mod 31), then add 41 to get a hole width in [41, 71]
  wire       ge31_1  = (random_num >= 8'd31);
  wire [7:0] diff1   = random_num - 8'd31;
  wire [7:0] tmp1    = ge31_1 ? diff1 : random_num;
  wire       ge31_2  = (tmp1 >= 8'd31);
  wire [7:0] diff2   = tmp1 - 8'd31;
  wire [4:0] rnd_mod = ge31_2 ? diff2[4:0] : tmp1[4:0];
  wire [6:0] new_w   = 7'd41 + rnd_mod; // Final computed hole width

  // State register: remembers if the game/hole motion has started
  wire       started, started_next;
  assign started_next = started | go_i;
  FDRE #(.INIT(1'b0)) ff_start (.C(clk_i), .CE(1'b1), .D(started_next), .Q(started), .R(reset_i));

  // Hole position tracking
  wire [10:0] pos, pos_next;
  wire [10:0] width_u  = {4'b0, hole_w};       // Zero-extend hole width to match pos bit-width
  wire [10:0] end_sum  = pos + width_u;        // Compute end position of hole

  assign hole_off_left = pos[10];              // Sign bit indicates position is off-screen left
  assign hole_end      = end_sum[10] ? 10'd0 : end_sum[9:0]; // Clip hole end if off screen

  wire off_left_edge = (end_sum == 11'd0);     // Check if hole has completely moved off screen

  // Compute next position: reset to 640 on start or when off screen, else move left if frame_tick
  assign pos_next = go_i          ? 11'd640 :
                    (!started)    ? 11'd640 :
                    off_left_edge ? 11'd640 :
                    frame_tick    ? pos - 11'd1 :
                    pos;

  FDRE #(.INIT(1'b0)) ff_p [10:0] (.C(clk_i),.CE(1'b1),.D(pos_next[10:0]),.Q(pos[10:0]),.R(reset_i));
 
  // Load new width when starting or when hole has moved off screen
  wire       load_w = off_left_edge | go_i;
  wire [6:0] w_next = load_w ? new_w : hole_w;

  FDRE #(.INIT(1'b0)) ff_w [6:0] (.C(clk_i),.CE(1'b1),.D(w_next[6:0]),.Q(hole_w[6:0]),.R(reset_i));

  // Output hole X coordinate (clip to 0 if off screen)
  assign hole_x = pos[10] ? 10'd0 : pos[9:0];

endmodule

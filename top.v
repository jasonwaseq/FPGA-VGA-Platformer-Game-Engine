`timescale 1ns / 1ps

module top (
  // Inputs: clock, buttons, switches
  input  wire        clkin,
  input  wire        btnR,  // Reset
  input  wire        btnL,  // Continue button
  input  wire        btnU,  // Jump button
  input  wire        btnC,  // Start/Action button
  input  wire [15:0] sw,    // Unused in this module
  // VGA outputs
  output wire        Hsync,
  output wire        Vsync,
  output wire [3:0]  vgaRed,
  output wire [3:0]  vgaGreen,
  output wire [3:0]  vgaBlue,
  // 7-segment display outputs
  output wire [3:0]  an,
  output wire [6:0]  seg,
  output wire        dp,
  // LEDs for lives display
  output wire [15:0] led,
  // HDMI outputs (mirrors VGA outputs)
  output      [3:0]  hdmiRed,
  output      [3:0]  hdmiGreen,
  output      [3:0]  hdmiBlue,
  output             hdmi_hsync,
  output             hdmi_vsync,
  output             hdmi_clk,
  output             hdmi_dispen
);

  // Clock divider and digit selector generator
  wire clk, digsel;
  labVGA_clks clkgen (.clkin(clkin), .greset(btnR), .clk(clk), .digsel(digsel));

  // Horizontal and vertical counters for VGA sync generation
  wire [9:0] x, y;
  wire       active, frame;
  syncs syncs (
    .clk    (clk),
    .reset  (btnR),
    .Hsync  (Hsync),
    .Vsync  (Vsync),
    .x      (x),
    .y      (y),
    .active (active),
    .frame  (frame)  // 1 tick per frame
  );

  // LFSR-based pseudo-random number generator for hole and ball
  wire [7:0] random_num;
  lfsr lfsr (
    .clk_i   (clk),
    .reset_i (btnR),
    .q_o     (random_num)
  );

  // Player x-position (constant)
  wire [9:0] PX       = 10'd100;
  wire [9:0] px_left  = PX + 10'd50;
  wire [9:0] px_right = px_left + 10'd15;

  // Hole parameters and overlap detection logic
  wire [9:0] hole_x, hole_end;
  wire [6:0] hole_w;
  wire       hole_off_left;
  wire over_hole_standard = !hole_off_left && (px_left >= hole_x) && (px_right <= hole_x + hole_w);
  wire over_hole_wrap     = hole_off_left && (px_left < hole_end) && (px_right > 10'd0);
  wire over_hole          = over_hole_standard || over_hole_wrap;

  // Falling state logic
  wire falling_q, next_falling;
  wire continue_i  = btnL && done_fall && (lives_q != 2'd0);
  wire gated_frame = frame & ~falling_q;

  // Debounce logic for center button (btnC)
  wire        c_pressed;
  wire        c_pressed_next = c_pressed | btnC;
  FDRE #(.INIT(1'b0)) ff_c_press (.C(clk), .CE(1'b1), .D(c_pressed_next), .Q(c_pressed), .R(btnR));

  // Trigger new hole generation
  wire hole_go = (btnC & ~c_pressed) || continue_i;

  // Hole controller generates new hole parameters each frame
  hole_controller hole_controller (
    .clk_i         (clk),
    .reset_i       (btnR),
    .frame_tick    (gated_frame),
    .go_i          (hole_go),
    .random_num    (random_num),
    .hole_x        (hole_x),
    .hole_w        (hole_w),
    .hole_off_left (hole_off_left),
    .hole_end      (hole_end)
  );

  // Player vertical movement logic (jumping and falling)
  wire player_reset = btnR || continue_i;
  wire [9:0] player_y;
  wire [6:0] power_h;
  player_controller player_controller (
    .clk_i      (clk),
    .reset_i    (player_reset),
    .btnU       (btnU & ~falling_q),
    .frame_tick (frame),
    .py_o       (player_y),
    .power_h    (power_h)
  );

  // Fall starts when player is over hole at a certain height
  wire start_fall = frame && (player_y == 10'd328) && over_hole;
  wire new_fall   = start_fall && !falling_q;

  // Fall animation: player y-position incrementally increases
  wire [9:0] py_disp_q, next_py_disp;
  FDRE #(.INIT(1'b0)) ff_py0 (.C(clk), .CE(frame), .D(next_py_disp[0]), .Q(py_disp_q[0]), .R(btnR || continue_i));
  FDRE ff_py [9:1]     (.C(clk), .CE(frame), .D(next_py_disp[9:1]), .Q(py_disp_q[9:1]), .R(btnR || continue_i));

  wire [9:0] step_down = (py_disp_q + 10'd2 <= 10'd440) ? py_disp_q + 10'd2 : 10'd440;
  assign next_py_disp = (frame && falling_q)  ? step_down :
                        (frame && start_fall) ? player_y  :
                         py_disp_q;

  // Done falling if reached bottom
  wire done_fall = falling_q && (py_disp_q == 10'd440);

  // Update falling state register
  assign next_falling = falling_q | start_fall;
  FDRE #(.INIT(1'b0)) ff_fall (.C(clk), .CE(1'b1), .D(next_falling), .Q(falling_q), .R(btnR || continue_i));

  // Life counter (decrease on fall, reset on reset)
  wire [1:0] lives_q;
  wire [1:0] lives_d = btnR     ? 2'd3 :
                       new_fall ? lives_q - 2'd1 :
                       lives_q;
  wire       lives_en = btnR || new_fall;
  FDRE #(.INIT(1'b1)) ff_life [1:0] (.C(clk), .CE(lives_en), .D(lives_d), .Q(lives_q), .R(1'b0));

  // Flashing effect logic when falling
  wire pf_q;
  wire [5:0] pf_cnt_q, pf_cnt_next;
  wire       flash_enable = falling_q || done_fall;
  wire       pf_end_cnt   = (pf_cnt_q == 6'd29) & frame & flash_enable;
  assign pf_cnt_next = pf_end_cnt            ? 6'd0 :
                      (frame & flash_enable) ? pf_cnt_q + 6'd1 :
                       pf_cnt_q;
  FDRE #(.INIT(1'b0)) ff_pc0 (.C(clk), .CE(1'b1), .D(pf_cnt_next[0]), .Q(pf_cnt_q[0]), .R(btnR || continue_i));
  FDRE ff_pc [5:1]     (.C(clk), .CE(1'b1), .D(pf_cnt_next[5:1]), .Q(pf_cnt_q[5:1]), .R(btnR || continue_i));

  // Toggle flash signal at end of count
  wire pf_d = pf_end_cnt ? ~pf_q : pf_q;
  FDRE #(.INIT(1'b0)) ff_pflash (.C(clk), .CE(1'b1), .D(pf_d), .Q(pf_q), .R(btnR || continue_i));

  // Ball controller: manages moving collectible object and scoring
  wire [7:0] score;
  wire [9:0] ball_x, ball_y;
  wire       ball_vis, ball_flash;

  wire [9:0] display_y = falling_q ? py_disp_q : player_y;
  wire [9:0] py_top    = display_y + 10'd16;
  wire [9:0] py_bottom = py_top + 10'd15;

  // Collision detection between player and ball
  wire overlap_h = (px_left < ball_x + 10'd8) && (px_right > ball_x);
  wire overlap_v = (py_top  < ball_y + 10'd8) && (py_bottom > ball_y);
  wire tag       = ball_vis && overlap_h && overlap_v;

  ball_controller ball_controller (
    .clk_i       (clk),
    .reset_i     (btnR),
    .frame_tick  (frame),
    .random_num  (random_num),
    .tag         (tag),
    .go_i        (hole_go),
    .ball_x      (ball_x),
    .ball_y      (ball_y),
    .ball_vis    (ball_vis),
    .ball_flash  (ball_flash),
    .score       (score)
  );

  // Converts game objects' states into pixel colors
  pixel_address pixel_address (
    .clk_i         (clk),
    .reset_i       (btnR),
    .active        (active),
    .x             (x),
    .y             (y),
    .px            (PX),
    .py            (display_y),
    .hole_x        (hole_x),
    .hole_w        (hole_w),
    .hole_off_left (hole_off_left),
    .hole_end      (hole_end),
    .coin_x        (10'd0), // Unused coin logic
    .coin_y        (10'd0),
    .tag           (tag),
    .power_h       (power_h),
    .ball_x        (ball_x),
    .ball_y        (ball_y),
    .ball_vis      (ball_vis & ~falling_q),
    .ball_flash    (ball_flash & ~falling_q),
    .player_flash  (pf_q),
    .vgaRed        (vgaRed),
    .vgaGreen      (vgaGreen),
    .vgaBlue       (vgaBlue)
  );

  // Score is passed to 7-segment display logic
  wire [15:0] N = {8'd0, score};  // Only display lower 8 bits
  wire [3:0]  data, h;

  // Display digit selector
  ring_counter ring_counter (
    .advance_i (digsel),
    .clk_i     (clk),
    .data_o    (data)
  );

  // Score digit selector for 7-seg
  selector selector (
    .N   (N),
    .sel (data),
    .H   (h)
  );

  // Converts digit to 7-segment segments
  hex7seg hex7seg (
    .n   (h),
    .seg (seg)
  );

  // Only enable 2 digits
  assign an[1:0] = ~data;
  assign an[3:2] = 2'b11;

  // Display lives with LEDs
  assign led[0]    = (lives_q > 2'd0);
  assign led[1]    = (lives_q > 2'd1);
  assign led[2]    = (lives_q > 2'd2);
  assign led[15:3] = 13'b0;

  assign dp = 1'b1;

  // HDMI mirroring VGA signals
  assign hdmiRed    = vgaRed;
  assign hdmiGreen  = vgaGreen;
  assign hdmiBlue   = vgaBlue;
  assign hdmi_hsync = Hsync;
  assign hdmi_vsync = Vsync;
  assign hdmi_clk   = clk;
  assign hdmi_dispen= active;

endmodule

`timescale 1ns / 1ps

module ball_controller (
  input  wire        clk_i,        // Clock input
  input  wire        reset_i,      // Asynchronous reset
  input  wire        frame_tick,   // Signal for each new video frame
  input  wire [7:0]  random_num,   // Random number input for Y position randomization
  input  wire        tag,          // Signal indicating a tag event (e.g., collision)
  input  wire        go_i,         // Start signal to launch or reload the ball

  output wire [9:0]  ball_x,       // Ball's X position
  output wire [9:0]  ball_y,       // Ball's Y position
  output wire        ball_vis,     // Whether the ball is visible
  output wire        ball_flash,   // Flashing effect during tag event
  output wire [7:0]  score         // Player score
);

  // Edge detector for tag signal
  wire tag_d;
  FDRE #(.INIT(1'b0)) tag_reg (.C(clk_i),.CE(1'b1),.D(tag),.Q(tag_d),.R(reset_i));
  wire tag_pulse = tag & ~tag_d; // Single-cycle pulse on rising edge of 'tag'

  // FSM state registers for move and flash modes
  wire move, flash, next_move, next_flash;
  FDRE #(.INIT(1'b0)) s0 (.C(clk_i), .CE(1'b1), .D(next_move), .Q(move), .R(reset_i));
  FDRE #(.INIT(1'b0)) s1 (.C(clk_i), .CE(1'b1), .D(next_flash), .Q(flash), .R(reset_i));

  // FSM mode conditions
  wire in_MOVE  = ~flash &  move;
  wire in_FLASH =  flash & ~move;

  // Detect when the ball has exited the left edge of the screen
  wire off_left = (ball_x < 10'd4);

  // Flash countdown counter logic
  wire [7:0] flash_cnt;
  wire flash_zero  = (flash_cnt == 8'd0); // Flash duration expired
  wire exit_flash  = in_FLASH & (frame_tick & flash_zero); // Exit flash mode on zero countdown
  wire reload_off  = (in_MOVE & off_left) | go_i; // Reload when ball exits screen or go_i is triggered
  wire to_FLASH    = in_MOVE & tag_pulse; // Transition to flash mode when tagged in move state

  // FSM transition logic
  assign next_move = (~flash & ~move & go_i) | ( in_MOVE & ~tag_pulse) | ( in_FLASH & exit_flash);
  assign next_flash = ( in_MOVE &  tag_pulse) | ( in_FLASH & ~exit_flash);

  // Flash counter update logic
  wire [7:0] nxt_flash_cnt = to_FLASH                ? 8'd119 :            // Reset to 119 on flash start
                             (in_FLASH & frame_tick) ? flash_cnt - 8'd1 :  // Decrement each frame in flash
                             flash_cnt;
  FDRE #(.INIT(1'b0)) fc [7:0] (.C(clk_i), .CE(1'b1), .D(nxt_flash_cnt[7:0]), .Q(flash_cnt[7:0]), .R(reset_i));

  // Score counter increments when exiting flash mode
  wire [7:0] nxt_score = score + (exit_flash ? 8'd1 : 8'd0);
  FDRE #(.INIT(1'b0)) sc0 [7:0] (.C(clk_i), .CE(1'b1), .D(nxt_score[7:0]), .Q(score[7:0]), .R(reset_i));

  // Ball position reload control logic
  wire to_move    = (~next_flash & next_move);  // Transitioning to move mode
  wire from_move  = in_MOVE;
  wire from_flash = in_FLASH;
  wire do_reload  = to_move & (from_flash | reload_off | ~from_move); // Conditions to reload position

  // Update X position: reset to right edge (640) on reload, decrement otherwise
  wire [9:0] dec_x = ball_x - 10'd4;
  wire [9:0] nxt_x = do_reload              ? 10'd640 :
                     (in_MOVE & frame_tick) ? dec_x :
                     ball_x;

  // Constrain random number to a 0-60 range for Y variation
  wire [5:0] raw6    = random_num[5:0];
  wire [5:0] rnd_mod = (raw6 <= 6'd60) ? raw6 : raw6 - 6'd61;

  // Update Y position: randomize vertical position on reload
  wire [9:0] nxt_y = do_reload ? (10'd192 + {4'b0, rnd_mod}) : ball_y;

  // Ball X position register
  FDRE #(.INIT(1'b0)) fx0 (.C(clk_i), .CE(1'b1), .D(nxt_x[0]), .Q(ball_x[0]), .R(1'b0));
  FDRE           fx [9:1] (.C(clk_i), .CE(1'b1), .D(nxt_x[9:1]), .Q(ball_x[9:1]), .R(1'b0));

  // Ball Y position register
  FDRE #(.INIT(1'b0)) fy0 (.C(clk_i), .CE(1'b1), .D(nxt_y[0]), .Q(ball_y[0]), .R(1'b0));
  FDRE           fy [9:1] (.C(clk_i), .CE(1'b1), .D(nxt_y[9:1]), .Q(ball_y[9:1]), .R(1'b0));

  // Output: ball visible if in move or flash mode
  assign ball_vis   = in_MOVE | in_FLASH;
  // Output: flashing effect (e.g., toggling color) during flash mode based on counter bit
  assign ball_flash = in_FLASH & flash_cnt[5];

endmodule

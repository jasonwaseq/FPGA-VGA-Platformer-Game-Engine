`timescale 1ns / 1ps

module pixel_address (
  input  wire        clk_i,             // Clock input
  input  wire        reset_i,           // Asynchronous reset input
  input  wire        active,            // Indicates active video display region
  input  wire [9:0]  x,                 // Current pixel x-coordinate
  input  wire [9:0]  y,                 // Current pixel y-coordinate
  input  wire [9:0]  px,                // Player's x-position
  input  wire [9:0]  py,                // Player's y-position
  input  wire [9:0]  hole_x,            // Starting x-coordinate of the hole
  input  wire [6:0]  hole_w,            // Width of the hole
  input  wire        hole_off_left,     // If set, hole is off the left edge
  input  wire [9:0]  hole_end,          // End x-coordinate of the hole when off-left
  input  wire [9:0]  coin_x,            // Coin x-position
  input  wire [9:0]  coin_y,            // Coin y-position
  input  wire        tag,               // Indicates if the player is "tagged"
  input  wire [6:0]  power_h,           // Power bar height
  input  wire [9:0]  ball_x,            // Ball x-position
  input  wire [9:0]  ball_y,            // Ball y-position
  input  wire        ball_vis,          // Ball visibility flag
  input  wire        ball_flash,        // Ball flash effect flag
  input  wire        player_flash,      // Player flash effect flag

  output wire [3:0]  vgaRed,            // VGA Red output
  output wire [3:0]  vgaGreen,          // VGA Green output
  output wire [3:0]  vgaBlue            // VGA Blue output
);

  // internal LFSR to pick random player colors
  wire [7:0] rand_color;
  lfsr lfsr_player (
    .clk_i   (clk_i),
    .reset_i (reset_i),
    .q_o     (rand_color)
  );

  // detect rising edge of tag
  wire tag_d;
  FDRE #(.INIT(1'b0)) tag_reg (.C(clk_i),.CE(1'b1),.D(tag),.Q(tag_d),.R(reset_i));
  wire tag_pulse = tag & ~tag_d;

  // hold the current player color
  wire [3:0] playerColorR, playerColorG, playerColorB;
  // split/mix rand bits into 3×4-bit channels
  wire [3:0] newColorR = rand_color[7:4];
  wire [3:0] newColorG = rand_color[3:0];
  wire [3:0] newColorB = rand_color[7:4] ^ rand_color[3:0];

  // generate a "load" when either reset_i or tag_pulse is high
  wire loadClr     = reset_i | tag_pulse;
  // when reset, pick original green default; otherwise the LFSR bits
  wire [3:0] loadR = reset_i ? 4'b0000 : newColorR;
  wire [3:0] loadG = reset_i ? 4'b1111 : newColorG;
  wire [3:0] loadB = reset_i ? 4'b0000 : newColorB;

  // hold the current player color
  FDRE #(.INIT(4'b0000)) ff_cr [3:0] (.C(clk_i),.CE(loadClr),.D(loadR),.Q(playerColorR),.R(1'b0));
  FDRE #(.INIT(4'b1111)) ff_cg [3:0] (.C(clk_i),.CE(loadClr),.D(loadG),.Q(playerColorG),.R(1'b0));
  FDRE #(.INIT(4'b0000)) ff_cb [3:0] (.C(clk_i),.CE(loadClr),.D(loadB),.Q(playerColorB),.R(1'b0));

  // Define pixel regions for rendering logic
  wire border         = (x < 8) || (x >= 632) || (y < 8) || (y >= 472);  // Screen border
  wire on_platform    = (y >= 360) && (y < 380) && !border;             // Flat platform region
  wire in_hole        = on_platform 
                        && ((!hole_off_left && x >= hole_x && x < hole_x + hole_w) 
                        || ( hole_off_left && x < hole_end));           // Hole cutout on platform
  wire in_hole_column = (!hole_off_left && x >= hole_x && x < hole_x + hole_w) 
                        || ( hole_off_left && x < hole_end);           // Vertical span of hole
  wire below_platform = (y >= 380) && !border && !in_hole_column;      // Region below platform (fall zone)
  wire in_player      = (x >= px+50) && (x < px+66) && (y >= py+16) && (y < py+32);  // Player rectangle
  wire in_coin        = (x >= coin_x) && (x < coin_x + 8) && (y >= coin_y) && (y < coin_y + 8);  // Coin region
  wire in_power_bar   = (x >= 32) && (x < 48) && (y >= 96 - power_h) && (y < 96);   // Vertical power bar
  wire in_ball        = ball_vis && (x >= ball_x) && (x < ball_x + 8) && (y >= ball_y) && (y < ball_y + 8);  // Ball display
  wire in_player_hit  = in_player && tag;                           // Player is tagged (hit)

  // VGA Red color logic based on pixel regions
  wire [3:0] vgaRedTemp =    (!active)                   ? 4'b0000 :  // Black when inactive
                             border                      ? 4'b1111 :  // Red border
                             below_platform              ? 4'b1000 :  // Fall zone
                             in_power_bar                ? 4'b0000 :  // Power bar
                             (in_player && player_flash) ? 4'b1111 :  // Flashing player
                             (in_ball   && ball_flash)   ? 4'b1111 :  // Flashing ball
                             in_ball                     ? 4'b1111 :  // Solid white ball
                             in_player                   ? playerColorR :  // Player
                             in_coin                     ? 4'b1111 :  // White coin
                             (on_platform && !in_hole)   ? 4'b0000 :  // Platform is black
                             4'b0000;                                 // Default black

  // VGA Green color logic
  wire [3:0] vgaGreenTemp =  (!active)                   ? 4'b0000 :  // Black when inactive
                             border                      ? 4'b0000 :  // Border has no green
                             below_platform              ? 4'b1000 :  // Fall zone
                             in_power_bar                ? 4'b1111 :  // Green power bar
                             (in_player && player_flash) ? 4'b1111 :  // Flashing player
                             in_player                   ? playerColorG :  // Player
                             (in_ball   && ball_flash)   ? 4'b1111 :  // Flashing ball
                             (in_ball   && !ball_flash)  ? 4'b1000 :  // Orange ball
                             in_coin                     ? 4'b1100 :  // Orange coin
                             in_hole                     ? 4'b0000 :  // Hole is black
                             (on_platform && !in_hole)   ? 4'b1000 :  // Platform
                             4'b0000;

  // VGA Blue color logic
  wire [3:0] vgaBlueTemp =   (!active)                   ? 4'b0000 :  // Black when inactive
                             border                      ? 4'b0000 :  // Border has no blue
                             below_platform              ? 4'b1000 :  // Fall zone
                             in_power_bar                ? 4'b0000 :  // No blue in power bar
                             (in_player && player_flash) ? 4'b1111 :  // Flashing player
                             in_player                   ? playerColorB :  // Player
                             (in_ball   && ball_flash)   ? 4'b1111 :  // Flashing ball
                             (in_ball   && !ball_flash)  ? 4'b0000 :  // No blue for normal ball
                             in_coin                     ? 4'b0000 :  // No blue for coin
                             (on_platform && !in_hole)   ? 4'b1000 :  // Platform
                             4'b0000;

  // Register outputs using flip-flops with async reset
  FDRE #(.INIT(1'b0)) ff_red   [3:0](.C(clk_i), .CE(1'b1), .D(vgaRedTemp),   .Q(vgaRed),   .R(reset_i));
  FDRE #(.INIT(1'b0)) ff_green [3:0](.C(clk_i), .CE(1'b1), .D(vgaGreenTemp), .Q(vgaGreen), .R(reset_i));
  FDRE #(.INIT(1'b0)) ff_blue  [3:0](.C(clk_i), .CE(1'b1), .D(vgaBlueTemp),  .Q(vgaBlue),  .R(reset_i));

endmodule

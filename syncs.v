`timescale 1ns / 1ps

module syncs (
  input  wire        clk,     // System clock
  input  wire        reset,   // Synchronous reset

  output wire        Hsync,   // Horizontal sync signal
  output wire        Vsync,   // Vertical sync signal
  output wire [15:0] x,       // Current horizontal pixel position
  output wire [15:0] y,       // Current vertical pixel position
  output wire        active,  // High during active video region
  output wire        frame    // High for 1 clock when a new frame starts
);

  // Horizontal counter (0 to 799)
  wire [15:0] hcnt, hcnt_next;
  wire        h_wrap    = (hcnt == 16'd799);              // End of horizontal line
  assign      hcnt_next = h_wrap ? 16'd0 : (hcnt + 16'd1); // Wrap or increment
  FDRE #(.INIT(1'b1)) ff_h [15:0] (.C(clk),.CE(1'b1),.D(hcnt_next),.Q(hcnt),.R(reset));

  // Vertical counter (0 to 524), increments once per horizontal wrap
  wire [15:0] vcnt, vcnt_next;
  wire        v_inc  = h_wrap;                            // Increment vcnt at end of line
  wire        v_wrap = v_inc && (vcnt == 16'd524);        // End of frame
  assign      vcnt_next = v_wrap ? 16'd0 :                // Wrap or increment or hold
                          v_inc  ? (vcnt + 16'd1) : 
                          vcnt;
  FDRE #(.INIT(1'b1)) ff_v [15:0] (.C(clk),.CE(1'b1),.D(vcnt_next),.Q(vcnt),.R(reset));

  // Horizontal sync pulse (active low between counts 656 and 751)
  wire Hsync_comb = ~((hcnt >= 16'd656) && (hcnt < 16'd752));
  // Vertical sync pulse (active low between counts 489 and 490)
  wire Vsync_comb = ~((vcnt >= 16'd489) && (vcnt < 16'd491));

  assign Hsync = Hsync_comb;
  assign Vsync = Vsync_comb;

  // Active video region (640x480)
  assign active = (hcnt < 16'd640) && (vcnt < 16'd480);

  // Output current pixel coordinates
  assign x = hcnt;
  assign y = vcnt;

  // Detect rising edge of Vsync to mark start of new frame
  wire Vprev;
  FDRE ff_vprev (.C(clk),.CE(1'b1),.D(Vsync),.Q(Vprev),.R(reset));
  assign frame = (~Vprev) && Vsync;

endmodule

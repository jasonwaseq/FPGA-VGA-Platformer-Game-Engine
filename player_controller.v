`timescale 1ns / 1ps

module player_controller (
  input  wire        clk_i,       // Clock input
  input  wire        reset_i,     // Synchronous reset
  input  wire        btnU,        // Jump button (Up button)
  input  wire        frame_tick,  // Frame tick signal (used as clock enable)
  
  output wire [9:0]  py_o,        // Player Y-position output
  output wire [6:0]  power_h      // Power/charge level output
);

  wire [9:0] py;                  // Internal player Y-position register
  wire [6:0] ph;                  // Internal power/charge register

  wire CE_ph = frame_tick;       // Clock enable for power logic
  wire CE_py = frame_tick | reset_i; // Clock enable for Y-position logic

  wire on_platform = (py == 10'd328); // Check if player is on the platform

  // Charging only when on the platform and button is pressed
  wire charging    = btnU && on_platform;
  // Discharging when power is non-zero and not charging
  wire discharging = (ph != 7'd0) && !charging;

  // Calculate next power value: increase if charging, decrease if discharging
  wire [6:0] ph_inc = ph + 7'd1;
  wire [6:0] ph_dec = ph - 7'd1;
  wire [6:0] next_ph = charging    ? (ph == 7'd64 ? 7'd64 : ph_inc) :
                       discharging ? ph_dec :
                       ph;

  // Define movement directions based on power level
  wire go_up   = discharging;
  wire go_down = (ph == 7'd0) && (py < 10'd328); // Gravity when out of power

  // Calculate next Y-position
  wire [9:0] py_up   = py - 10'd2;
  wire [9:0] py_down = py + 10'd2;
  wire [9:0] next_py = reset_i  ? 10'd328 :       // Reset position
                       charging ? 10'd328 :       // Stay on platform while charging
                       go_up    ? py_up   :       // Move up when discharging
                       go_down  ? py_down :       // Fall down otherwise
                       py;

  // Power register (7-bit flip-flop array)
  FDRE #(.INIT(1'b0)) ph_ff [6:0] (.C(clk_i), .CE(CE_ph), .D(next_ph[6:0]), .Q(ph[6:0]), .R(reset_i));
  
  // Y-position register (10-bit flip-flop, explicitly instantiated per bit)
  FDRE #(.INIT(1'b0)) py_ff0 (.C(clk_i), .CE(CE_py), .D(next_py[0]), .Q(py[0]), .R(1'b0));
  FDRE #(.INIT(1'b0)) py_ff1 (.C(clk_i), .CE(CE_py), .D(next_py[1]), .Q(py[1]), .R(1'b0));
  FDRE #(.INIT(1'b0)) py_ff2 (.C(clk_i), .CE(CE_py), .D(next_py[2]), .Q(py[2]), .R(1'b0));
  FDRE #(.INIT(1'b1)) py_ff3 (.C(clk_i), .CE(CE_py), .D(next_py[3]), .Q(py[3]), .R(1'b0));
  FDRE #(.INIT(1'b0)) py_ff4 (.C(clk_i), .CE(CE_py), .D(next_py[4]), .Q(py[4]), .R(1'b0));
  FDRE #(.INIT(1'b0)) py_ff5 (.C(clk_i), .CE(CE_py), .D(next_py[5]), .Q(py[5]), .R(1'b0));
  FDRE #(.INIT(1'b1)) py_ff6 (.C(clk_i), .CE(CE_py), .D(next_py[6]), .Q(py[6]), .R(1'b0));
  FDRE #(.INIT(1'b0)) py_ff7 (.C(clk_i), .CE(CE_py), .D(next_py[7]), .Q(py[7]), .R(1'b0));
  FDRE #(.INIT(1'b1)) py_ff8 (.C(clk_i), .CE(CE_py), .D(next_py[8]), .Q(py[8]), .R(1'b0));
  FDRE #(.INIT(1'b0)) py_ff9 (.C(clk_i), .CE(CE_py), .D(next_py[9]), .Q(py[9]), .R(1'b0));

  assign py_o    = py;  // Output current Y-position
  assign power_h = ph;  // Output current power level

endmodule

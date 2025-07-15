# FPGA-VGA-Platformer-Game-Engine

## Description:
Developed a fully functional version of the arcade-style game “Watch Your Step” on the Digilent BASYS3 FPGA board, using Verilog to drive a VGA display and implement real-time game logic. Designed synchronous VGA controllers to generate Hsync/Vsync signals and pixel coordinates for a 640×480 active region, then built modular combinational and sequential logic—using only assign statements for combinational behavior and FDRE flip-flops for sequential elements—to manage player movement, jump mechanics with a power bar, dynamic hole generation, and random ball spawning. Integrated state machines to handle game states (idle, active play, ball tagging, and game over), ensured correct flashing and collision detection, and displayed the player’s score on two 7-segment digits. This assignment demonstrated proficiency in digital design principles, timing-driven implementation, hardware-verified randomization, and on-chip VGA interfacing for embedded game applications.
## Demos:
https://www.youtube.com/watch?v=9thiTSjArsI   
https://www.youtube.com/watch?v=DlOItQ2Bdhg

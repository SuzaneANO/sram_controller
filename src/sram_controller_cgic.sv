// Negative-Edge Latch Clock Gating Integrated Circuit
// Story 2.1: Implement Negative-Edge Latch CGIC Module
// Module: sram_controller_cgic
// File: rtl/sram_controller_cgic.sv
// RTL will be synthesized to Sky130 HD cells (dlxtp_1 for latch, and2_1 for AND)

`default_nettype none

module sram_controller_cgic (
    input  logic clk,         // Original clock
    input  logic reset_n,     // Reset (active-low) - ensures safe power-on state
    input  logic enable,      // Clock enable signal
    output logic clk_gated    // Gated clock output
);

    // Negative-edge triggered latch for enable signal
    // Synthesis will map to Sky130 HD cell: sky130_fd_sc_hd_dlxtp_1
    logic enable_lat;

    // Negative-edge transparent latch
    // Latch is transparent when clk is low, holds value when clk is high
    always_latch begin
        if (!reset_n) begin
            enable_lat <= 1'b0;  // Safe default: clock gated on reset
        end else if (!clk) begin
            enable_lat <= enable;
        end else begin
            enable_lat <= enable_lat;  // Hold value when clk is high
        end
    end

    // AND gate for clock gating
    // Synthesis will map to Sky130 HD cell: sky130_fd_sc_hd_and2_1
    assign clk_gated = clk & enable_lat;

endmodule

`default_nettype wire

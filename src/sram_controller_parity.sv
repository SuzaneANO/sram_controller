// Parity Logic Module for Data Integrity & Error Detection
// Epic 6: Data Integrity & Error Detection
// Stories 6.1, 6.2: Odd Parity Generation and Checking
// Module: sram_controller_parity
// File: rtl/sram_controller_parity.sv

`default_nettype none

module sram_controller_parity (
    input  logic        clk,
    input  logic        reset_n,
    // Write data path (from AHB-Lite)
    input  logic [31:0] wdata,              // Write data (32-bit)
    input  logic        write_enable,       // Write operation enable
    input  logic [7:0]  waddr,              // Write address (for parity storage)
    // Read data path (from SRAM)
    input  logic [31:0] rdata,              // Read data (32-bit)
    input  logic        read_enable,        // Read operation enable
    input  logic [7:0]  raddr,              // Read address (for parity lookup)
    // Parity storage interface
    output logic        parity_out,         // Generated parity (for storage)
    input  logic        parity_in,          // Stored parity (from parity memory)
    // Error detection
    output logic        parity_error        // Parity error flag
);

    // Odd parity generation: XOR all bits, then invert for odd parity
    // Odd parity: Total number of 1s (including parity bit) is odd
    logic parity_gen;
    
    // Generate odd parity for write data
    // XOR reduction gives even parity, invert for odd parity
    assign parity_gen = ^wdata;  // XOR reduction (even parity)
    assign parity_out = !parity_gen;  // Invert for odd parity
    
    // Odd parity checking: XOR read data with stored parity
    // For odd parity: XOR(data) XOR parity_in should equal 1
    logic parity_check;
    logic parity_mismatch;
    
    // Check parity: XOR reduction of read data
    assign parity_check = ^rdata;  // XOR reduction (even parity)
    
    // Parity mismatch: For odd parity, parity_check XOR parity_in should equal 1
    // If mismatch, then (parity_check XOR parity_in) != 1
    assign parity_mismatch = (parity_check ^ parity_in) != 1'b1;
    
    // Parity error detection: Assert error if mismatch detected during read
    // Error detection completes within 1 clock cycle (NFR9)
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            parity_error <= 1'b0;
        end else begin
            if (read_enable) begin
                // Check parity on read operations
                parity_error <= parity_mismatch;
            end else begin
                // Clear error when not reading
                parity_error <= 1'b0;
            end
        end
    end

endmodule

`default_nettype wire

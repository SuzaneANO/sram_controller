// Parity Storage Module
// Stores parity bits for 256 SRAM words (256 parity bits = 32 bytes)
// Module: sram_controller_parity_storage
// File: rtl/sram_controller_parity_storage.sv

`default_nettype none

module sram_controller_parity_storage (
    input  logic        clk,
    input  logic        reset_n,
    // Write interface
    input  logic        write_enable,
    input  logic [7:0]  write_addr,
    input  logic        write_parity,
    // Read interface
    input  logic [7:0]  read_addr,
    output logic        read_parity
);

    // Parity storage: 256 bits (one per SRAM word)
    // Organized as 32 bytes (8 bits per byte) for efficient storage
    logic [7:0] parity_mem [0:31];  // 32 bytes × 8 bits = 256 parity bits
    
    // Write parity
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            for (int i = 0; i < 32; i++) begin
                parity_mem[i] <= 8'h0;
            end
        end else if (write_enable) begin
            // Store parity bit in appropriate byte/bit location
            parity_mem[write_addr[7:3]][write_addr[2:0]] <= write_parity;
        end
    end
    
    // Read parity (combinational)
    assign read_parity = parity_mem[read_addr[7:3]][read_addr[2:0]];

endmodule

`default_nettype wire

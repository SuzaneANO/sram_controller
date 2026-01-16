// AHB-Lite Protocol Interface Module
// Epic 5: AHB-Lite Protocol Interface
// Stories 5.1, 5.2, 5.3, 5.4: AHB-Lite Slave with Falling-Edge Sampling and Power-Aware Gating
// Module: sram_controller_ahb_lite
// File: rtl/sram_controller_ahb_lite.sv

`default_nettype none

module sram_controller_ahb_lite (
    // AHB-Lite Slave Interface (AMBA Specification)
    input  logic        hclk,              // AHB clock
    input  logic        hreset_n,          // AHB reset (active-low)
    input  logic        hsel,              // Slave select
    input  logic [7:0]  haddr,             // Address (8-bit for 256-word SRAM)
    input  logic        hwrite,            // Write enable
    input  logic [1:0]  htrans,            // Transfer type
    input  logic [2:0]  hsize,             // Transfer size
    input  logic [31:0] hwdata,            // Write data
    output logic [31:0] hrdata,            // Read data
    output logic        hready,            // Transfer ready (handshaking)
    output logic        hresp,             // Transfer response (always OKAY in MVP)
    
    // FSM Integration (Power State Management)
    input  logic        hready_gate,       // HREADY gating from FSM (low during WAKEUP)
    input  logic [1:0]  fsm_state,         // FSM state (for verification)
    
    // SRAM Macro Interface (matches Liberty file pin names)
    output logic        sram_clk0,         // SRAM clock (falling-edge triggered)
    output logic        sram_csb0,         // Chip select (active-low)
    output logic        sram_web0,         // Write enable (active-low)
    output logic [7:0]  sram_addr0,        // SRAM address
    output logic [31:0] sram_din0,         // SRAM write data
    output logic [3:0]  sram_wmask0,       // Write mask (byte enables)
    input  logic [31:0] sram_dout0,        // SRAM read data (changes on falling edge of clk0)
    
    // Parity Integration (Epic 6)
    output logic        parity_error       // Parity error flag (for top-level interface)
);

    // Internal signals
    logic valid_transfer;                  // Valid AHB transfer (hsel && htrans[1])
    logic read_enable;                     // Read operation enable
    logic write_enable;                    // Write operation enable
    logic [31:0] hrdata_reg;               // Registered read data
    logic [31:0] hrdata_falling;          // Falling-edge captured read data
    
    // Parity integration signals (Epic 6)
    logic parity_out;                      // Generated parity for write
    logic parity_in;                       // Stored parity for read
    logic parity_write_en;                 // Parity write enable
    logic parity_read_en;                  // Parity read enable
    
    // Address decoding: 8-bit address for 256-word SRAM
    // Address range: 0x00 to 0xFF (256 words × 4 bytes = 1KB)
    assign sram_addr0 = haddr[7:0];
    
    // Transfer validation: Valid when selected and non-idle transfer
    assign valid_transfer = hsel && htrans[1];  // htrans[1] = 1 for NONSEQ/SEQ
    
    // Read/Write control
    assign read_enable  = valid_transfer && !hwrite;
    assign write_enable = valid_transfer && hwrite;
    
    // SRAM control signals
    assign sram_csb0 = !valid_transfer;   // Chip select active-low (asserted when valid transfer)
    assign sram_web0 = !write_enable;     // Write enable active-low (asserted for writes)
    
    // SRAM clock: Use controller clock (will be gated by CGIC in full system)
    assign sram_clk0 = hclk;
    
    // Write data and mask
    assign sram_din0 = hwdata;
    
    // Write mask generation from address and hsize
    // hsize: 000=byte, 001=halfword, 010=word, 011=2 words, etc.
    // For 32-bit word writes, all bytes enabled
    // For byte/halfword writes, enable specific bytes based on address[1:0]
    always_comb begin
        case (hsize)
            3'b000: begin  // Byte (8-bit)
                case (haddr[1:0])
                    2'b00: sram_wmask0 = 4'b0001;  // Byte 0
                    2'b01: sram_wmask0 = 4'b0010;  // Byte 1
                    2'b10: sram_wmask0 = 4'b0100;  // Byte 2
                    2'b11: sram_wmask0 = 4'b1000;  // Byte 3
                endcase
            end
            3'b001: begin  // Halfword (16-bit)
                sram_wmask0 = haddr[1] ? 4'b1100 : 4'b0011;  // Upper or lower halfword
            end
            default: begin  // Word (32-bit) or larger
                sram_wmask0 = 4'b1111;  // All bytes enabled
            end
        endcase
    end
    
    // CRITICAL: Falling-Edge Sampling for HRDATA (NFR3, FR20)
    // SRAM dout0 changes on falling edge of clk0 per Liberty file timing
    // Capture on falling edge to meet half-cycle margin (12.5 ns) requirement
    always_ff @(negedge hclk or negedge hreset_n) begin
        if (!hreset_n) begin
            hrdata_falling <= 32'h0;
        end else begin
            if (read_enable) begin
                hrdata_falling <= sram_dout0;  // Capture on falling edge
            end
        end
    end
    
    // Register falling-edge captured data for AHB output
    // This provides additional pipeline stage for timing closure
    always_ff @(posedge hclk or negedge hreset_n) begin
        if (!hreset_n) begin
            hrdata_reg <= 32'h0;
        end else begin
            hrdata_reg <= hrdata_falling;
        end
    end
    
    // AHB read data output
    assign hrdata = hrdata_reg;
    
    // HREADY handshaking with power-aware gating (FR7, Story 5.3)
    // CRITICAL: HREADY must be low during WAKEUP state (via hready_gate)
    // HREADY indicates transaction completion and SRAM readiness
    always_comb begin
        if (!hready_gate) begin
            // Power-aware gating: Block HREADY during WAKEUP
            hready = 1'b0;
        end else if (valid_transfer) begin
            // Valid transfer: HREADY high after one cycle (pipelined)
            hready = 1'b1;
        end else begin
            // Idle or no transfer: HREADY high (ready for next transfer)
            hready = 1'b1;
        end
    end
    
    // Transfer response: Always OKAY in MVP (no error responses)
    assign hresp = 1'b0;  // 0 = OKAY, 1 = ERROR (not used in MVP)
    
    // ============================================================================
    // Epic 6: Parity Integration (Story 6.3)
    // ============================================================================
    
    // Parity write enable: Enable parity generation on writes
    assign parity_write_en = write_enable;
    
    // Parity read enable: Enable parity checking on reads
    assign parity_read_en = read_enable;
    
    // Instantiate parity logic module
    sram_controller_parity i_parity (
        .clk(hclk),
        .reset_n(hreset_n),
        .wdata(hwdata),                    // Write data from AHB-Lite
        .write_enable(parity_write_en),
        .waddr(haddr),
        .rdata(hrdata_reg),                 // Read data from SRAM (after falling-edge capture)
        .read_enable(parity_read_en),
        .raddr(haddr),
        .parity_out(parity_out),           // Generated parity (to storage)
        .parity_in(parity_in),             // Stored parity (from storage)
        .parity_error(parity_error)        // Parity error flag (to top-level)
    );
    
    // Instantiate parity storage module
    sram_controller_parity_storage i_parity_storage (
        .clk(hclk),
        .reset_n(hreset_n),
        .write_enable(parity_write_en),
        .write_addr(haddr),
        .write_parity(parity_out),
        .read_addr(haddr),
        .read_parity(parity_in)
    );

endmodule

`default_nettype wire

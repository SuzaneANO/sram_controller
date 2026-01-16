// Top-Level SRAM Controller Module
// Epic 7: OpenLane Integration & Physical Design
// Story 7.1: Create Top-Level Module Integrating All Components
// Module: sram_controller
// File: rtl/sram_controller.sv

`default_nettype none

module sram_controller (
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
    
    // PMU Interface (Power Management Unit)
    input  logic        clk_pmu,           // PMU clock domain
    input  logic        pwr_save_req,      // Power save request (PMU domain)
    input  logic        pwr_restore_req,   // Power restore request (PMU domain)
    
    // SRAM Macro Interface (matches sky130_sram_1kbyte_1rw1r_32x256_8 pinout)
    // Note: sram_dout0 is internal (driven by SRAM macro), not a module port
    output logic        sram_clk0,         // SRAM clock (falling-edge triggered)
    output logic        sram_csb0,         // Chip select (active-low)
    output logic        sram_web0,         // Write enable (active-low)
    output logic [7:0]  sram_addr0,        // SRAM address
    output logic [31:0] sram_din0,         // SRAM write data
    output logic [3:0]  sram_wmask0,       // Write mask (byte enables)
    
    // Power Domain Pins (for OpenLane power grid hookup)
    // Controller logic: vccd1 (always-on domain)
    // SRAM array: vccd2 (independently gated domain)
    inout  logic        vccd1,             // Controller power domain
    inout  logic        vssd1,             // Controller ground domain
    inout  logic        vccd2,             // SRAM power domain (gated)
    inout  logic        vssd2,             // SRAM ground domain
    
    // Status and Error Outputs
    output logic        parity_error,      // Parity error flag (from parity logic)
    output logic [1:0]  fsm_state          // FSM state (for debug/monitoring)
);

    // Internal clock and reset
    logic clk_ctrl;                        // Controller clock (from CGIC)
    logic reset_n;                         // Internal reset (synchronized)
    
    // PMU Synchronizer signals
    logic pwr_save_req_sync;               // Synchronized power save request
    logic pwr_restore_req_sync;           // Synchronized power restore request
    
    // FSM signals
    logic [1:0] fsm_state_int;             // Internal FSM state
    logic isolation_en;                   // Isolation cell enable
    logic power_gate_en;                  // Power gate enable (controls vccd2)
    logic hready_gate;                    // HREADY gating signal
    logic timer_enable;                   // Timer enable signal
    
    // Wakeup Timer signals
    logic timer_done;                     // Timer completion signal
    logic [1:0] timer_count;              // Timer count (debug)
    
    // Clock Gating signals
    logic cgic_enable;                    // CGIC enable (from FSM state)
    logic clk_gated;                      // Gated clock output
    
    // AHB-Lite internal signals
    logic parity_error_int;               // Internal parity error
    
    // SRAM Macro Interface (internal signals)
    logic [31:0] sram_dout0;              // SRAM read data (driven by SRAM macro output)
    logic [31:0] sram_dout1_unused;       // Unused SRAM port 1 output (dummy wire for Verilator)
    
    // Reset synchronization (simple - can be enhanced)
    assign reset_n = hreset_n;
    
    // Clock: Use AHB clock as controller clock (will be gated by CGIC)
    assign clk_ctrl = hclk;
    
    // CGIC enable: Gate clock during SLEEP state
    assign cgic_enable = (fsm_state_int != 2'b01);  // Enable when not in SLEEP
    
    // ============================================================================
    // Module Instantiations (Chief's Priority Sequence)
    // ============================================================================
    
    // 1. PMU Synchronizer (Foundation #1)
    sram_controller_pmu_sync i_pmu_sync (
        .clk_pmu(clk_pmu),
        .clk_ctrl(clk_ctrl),
        .reset_n(reset_n),
        .pwr_save_req(pwr_save_req),
        .pwr_restore_req(pwr_restore_req),
        .pwr_save_req_sync(pwr_save_req_sync),
        .pwr_restore_req_sync(pwr_restore_req_sync)
    );
    
    // 2. Clock Gating CGIC (Foundation #2)
    sram_controller_cgic i_cgic (
        .clk(clk_ctrl),
        .reset_n(reset_n),
        .enable(cgic_enable),
        .clk_gated(clk_gated)
    );
    
    // 3. Wakeup Timer (Foundation #3)
    sram_controller_wakeup_timer i_wakeup_timer (
        .clk(clk_ctrl),
        .reset_n(reset_n),
        .enable(timer_enable),
        .timer_done(timer_done),
        .timer_count(timer_count)
    );
    
    // 4. Power State Machine (Integration)
    sram_controller_fsm i_fsm (
        .clk(clk_ctrl),
        .reset_n(reset_n),
        .pwr_save_req_sync(pwr_save_req_sync),
        .pwr_restore_req_sync(pwr_restore_req_sync),
        .timer_done(timer_done),
        .fsm_state(fsm_state_int),
        .isolation_en(isolation_en),
        .power_gate_en(power_gate_en),
        .hready_gate(hready_gate),
        .timer_enable(timer_enable)
    );
    
    // 5. AHB-Lite Interface (Integration)
    sram_controller_ahb_lite i_ahb_lite (
        .hclk(hclk),
        .hreset_n(hreset_n),
        .hsel(hsel),
        .haddr(haddr),
        .hwrite(hwrite),
        .htrans(htrans),
        .hsize(hsize),
        .hwdata(hwdata),
        .hrdata(hrdata),
        .hready(hready),
        .hresp(hresp),
        .hready_gate(hready_gate),
        .fsm_state(fsm_state_int),
        .sram_clk0(sram_clk0),
        .sram_csb0(sram_csb0),
        .sram_web0(sram_web0),
        .sram_addr0(sram_addr0),
        .sram_din0(sram_din0),
        .sram_wmask0(sram_wmask0),
        .sram_dout0(sram_dout0),
        .parity_error(parity_error_int)
    );
    
    // ============================================================================
    // SRAM Macro Instantiation (sky130_sram_1kbyte_1rw1r_32x256_8)
    // ============================================================================
    
    // SRAM Macro: sky130_sram_1kbyte_1rw1r_32x256_8
    // Port 0 (Read-Write): Used for controller interface
    // Port 1 (Read-Only): Not used, tie off
    // Power: vccd2/vssd2 for SRAM array (gated domain, controlled by power_gate_en)
    
    sky130_sram_1kbyte_1rw1r_32x256_8 sram0 (
`ifdef USE_POWER_PINS
        .vccd1(vccd1),      // Controller power (always-on)
        .vssd1(vssd1),      // Controller ground
        .vccd2(vccd2),      // SRAM power (gated domain)
        .vssd2(vssd2),      // SRAM ground
`endif
        // Port 0 (Read-Write) - Controller Interface
        .clk0(sram_clk0),           // SRAM clock (falling-edge triggered)
        .csb0(sram_csb0),           // Chip select (active-low)
        .web0(sram_web0),           // Write enable (active-low)
        .wmask0(sram_wmask0),       // Write mask (byte enables)
        .addr0(sram_addr0),         // Address (8-bit for 256 words)
        .din0(sram_din0),           // Write data (32-bit)
        .dout0(sram_dout0),         // Read data (32-bit, changes on falling edge)
        
        // Port 1 (Read-Only) - Not used, tie off
        .clk1(1'b0),                // Tied low (not used)
        .csb1(1'b1),                // Tied high (disabled)
        .addr1(8'h0),               // Tied to 0 (not used)
        .dout1(sram_dout1_unused)   // Unused port (connected to dummy wire)
    );
    
    // Power Domain Control:
    // - isolation_en: Controls isolation cells between vccd1 and vccd2
    // - power_gate_en: Controls vccd2 power gating (asserted in SLEEP state)
    // - These are handled by PMU/Isolation cells in physical design
    
    // ============================================================================
    // Output Assignments
    // ============================================================================
    
    assign parity_error = parity_error_int;
    assign fsm_state = fsm_state_int;
    
    // Power domain connections:
    // - vccd1/vssd1: Always-on domain (controller logic)
    // - vccd2/vssd2: Gated domain (SRAM array, controlled by power_gate_en)
    // These are inout ports for OpenLane power grid hookup via FP_PDN_MACRO_HOOKS

endmodule

`default_nettype wire

// 3-Stage PMU Synchronizer Module
// Story 1.1: Implement 3-Stage PMU Synchronizer Module
// Module: sram_controller_pmu_sync
// File: rtl/sram_controller_pmu_sync.sv

`default_nettype none

module sram_controller_pmu_sync (
    input  logic clk_pmu,              // PMU clock domain
    input  logic clk_ctrl,             // Controller clock domain
    input  logic reset_n,
    input  logic pwr_save_req,          // PMU domain input
    input  logic pwr_restore_req,       // PMU domain input
    output logic pwr_save_req_sync,     // Controller domain output
    output logic pwr_restore_req_sync    // Controller domain output
);

    // Synchronizer flip-flops for pwr_save_req
    // ASYNC_REG attribute prevents synthesis from optimizing away synchronizer stages
    (* ASYNC_REG = "TRUE" *)
    logic pwr_save_req_meta;
    
    (* ASYNC_REG = "TRUE" *)
    logic pwr_save_req_sync1;
    
    (* ASYNC_REG = "TRUE" *)
    logic pwr_save_req_sync2;

    always_ff @(posedge clk_ctrl or negedge reset_n) begin
        if (!reset_n) begin
            pwr_save_req_meta  <= 1'b0;
            pwr_save_req_sync1 <= 1'b0;
            pwr_save_req_sync2 <= 1'b0;
        end else begin
            pwr_save_req_meta  <= pwr_save_req;      // Stage 1: Metastable
            pwr_save_req_sync1 <= pwr_save_req_meta; // Stage 2: Stable (high prob)
            pwr_save_req_sync2 <= pwr_save_req_sync1; // Stage 3: Stable (very high prob)
        end
    end

    assign pwr_save_req_sync = pwr_save_req_sync2;

    // Synchronizer flip-flops for pwr_restore_req (same structure)
    // ASYNC_REG attribute prevents synthesis from optimizing away synchronizer stages
    (* ASYNC_REG = "TRUE" *)
    logic pwr_restore_req_meta;
    
    (* ASYNC_REG = "TRUE" *)
    logic pwr_restore_req_sync1;
    
    (* ASYNC_REG = "TRUE" *)
    logic pwr_restore_req_sync2;

    always_ff @(posedge clk_ctrl or negedge reset_n) begin
        if (!reset_n) begin
            pwr_restore_req_meta  <= 1'b0;
            pwr_restore_req_sync1 <= 1'b0;
            pwr_restore_req_sync2 <= 1'b0;
        end else begin
            pwr_restore_req_meta  <= pwr_restore_req;
            pwr_restore_req_sync1 <= pwr_restore_req_meta;
            pwr_restore_req_sync2 <= pwr_restore_req_sync1;
        end
    end

    assign pwr_restore_req_sync = pwr_restore_req_sync2;

endmodule

`default_nettype wire

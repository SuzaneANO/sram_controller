// Power State Machine Module
// Epic 4: Power State Management
// Stories 4.1, 4.2, 4.3: 3-State FSM with Integration and Power Sequencing
// Module: sram_controller_fsm
// File: rtl/sram_controller_fsm.sv

`default_nettype none

module sram_controller_fsm (
    input  logic        clk,
    input  logic        reset_n,
    // PMU Synchronizer inputs (from sram_controller_pmu_sync)
    input  logic        pwr_save_req_sync,      // Synchronized power save request
    input  logic        pwr_restore_req_sync,   // Synchronized power restore request
    // Wakeup Timer input (from sram_controller_wakeup_timer)
    input  logic        timer_done,             // Timer completion signal
    // State outputs
    output logic [1:0]  fsm_state,               // Current FSM state
    // Power sequencing control signals
    output logic        isolation_en,           // Isolation cell enable
    output logic        power_gate_en,          // Power gate enable (controls vccd2)
    output logic        hready_gate,            // HREADY gating signal (low during WAKEUP)
    // Timer control output
    output logic        timer_enable            // Enable signal for wakeup timer
);

    // State encoding: ACTIVE=2'b00, SLEEP=2'b01, WAKEUP=2'b10, INVALID=2'b11
    typedef enum logic [1:0] {
        ACTIVE = 2'b00,
        SLEEP  = 2'b01,
        WAKEUP = 2'b10
        // 2'b11 is invalid state - FSM must never enter this
    } fsm_state_t;

    fsm_state_t current_state, next_state;

    // State register
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            current_state <= ACTIVE;  // Safe default: start in ACTIVE state
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic
    always_comb begin
        next_state = current_state;  // Default: hold current state
        
        case (current_state)
            ACTIVE: begin
                // ACTIVE → SLEEP: On power save request
                if (pwr_save_req_sync) begin
                    next_state = SLEEP;
                end else begin
                    next_state = ACTIVE;
                end
            end
            
            SLEEP: begin
                // SLEEP → WAKEUP: On power restore request
                if (pwr_restore_req_sync) begin
                    next_state = WAKEUP;
                end else begin
                    next_state = SLEEP;
                end
            end
            
            WAKEUP: begin
                // WAKEUP → ACTIVE: Only after timer completes
                if (timer_done) begin
                    next_state = ACTIVE;
                end else begin
                    next_state = WAKEUP;  // Wait for timer
                end
            end
            
            default: begin
                // Invalid state - force to ACTIVE (safety)
                next_state = ACTIVE;
            end
        endcase
    end

    // Output logic: Power sequencing control signals
    always_comb begin
        // Default values
        isolation_en = 1'b0;
        power_gate_en = 1'b0;
        hready_gate = 1'b1;  // Default: allow HREADY (ACTIVE state)
        timer_enable = 1'b0;
        
        case (current_state)
            ACTIVE: begin
                isolation_en = 1'b0;      // No isolation in ACTIVE
                power_gate_en = 1'b0;     // Power on (vccd2 active)
                hready_gate = 1'b1;       // Allow HREADY
                timer_enable = 1'b0;      // Timer disabled
            end
            
            SLEEP: begin
                isolation_en = 1'b1;      // Isolation cells enabled
                power_gate_en = 1'b1;    // Power gate enabled (vccd2 off)
                hready_gate = 1'b0;      // Block HREADY (no transactions)
                timer_enable = 1'b0;     // Timer disabled
            end
            
            WAKEUP: begin
                isolation_en = 1'b1;      // Isolation still enabled during wakeup
                power_gate_en = 1'b0;    // Power restored (vccd2 on)
                hready_gate = 1'b0;      // CRITICAL: Block HREADY during WAKEUP (FR7)
                timer_enable = 1'b1;     // Enable wakeup timer
            end
            
            default: begin
                // Invalid state - safe defaults
                isolation_en = 1'b1;      // Conservative: enable isolation
                power_gate_en = 1'b0;    // Conservative: power on
                hready_gate = 1'b0;      // Conservative: block HREADY
                timer_enable = 1'b0;
            end
        endcase
    end

    // State output (for external modules)
    assign fsm_state = current_state;

endmodule

`default_nettype wire

// 4-Cycle Wakeup Timer Module with Safety Lock
// Story 3.1: Implement 4-Cycle Wakeup Timer Module
// Module: sram_controller_wakeup_timer
// File: rtl/sram_controller_wakeup_timer.sv

`default_nettype none

module sram_controller_wakeup_timer (
    input  logic        clk,
    input  logic        reset_n,
    input  logic        enable,           // Asserted when FSM enters WAKEUP
    output logic        timer_done,       // Asserted after 4 cycles
    // FSM INTERLOCK: This timer_done signal MUST be used by the FSM to:
    // 1. Gate HREADY low during WAKEUP state (FR7)
    // 2. Prevent AHB transactions until timer completes (FR19)
    // 3. Block state transition WAKEUP→ACTIVE until timer_done asserted
    output logic [1:0]  timer_count       // Debug: current count (0-3)
);

    logic [1:0] count;
    logic       done;
    logic       safety_lock;  // Safety lock to prevent premature completion

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            count       <= 2'b00;
            done        <= 1'b0;
            safety_lock <= 1'b0;
        end else if (enable) begin
            // Safety lock: Must count through all 4 cycles before asserting done
            if (count == 2'b11) begin
                count       <= 2'b11;  // Hold at 3
                safety_lock <= 1'b1;   // Lock enabled after 4 cycles
                done        <= 1'b1;    // Assert done only after safety lock
            end else begin
                count       <= count + 1'b1;
                done        <= 1'b0;
                safety_lock <= 1'b0;
            end
        end else begin
            count       <= 2'b00;       // Reset when disabled
            done        <= 1'b0;
            safety_lock <= 1'b0;
        end
    end

    // Timer done only asserted when safety lock is active
    assign timer_done  = done && safety_lock;
    assign timer_count = count;

endmodule

`default_nettype wire

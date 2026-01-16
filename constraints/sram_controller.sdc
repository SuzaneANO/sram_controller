# SDC Timing Constraints for SRAM Controller
# Story 7.3: Create Complete SDC Timing Constraints File
# File: constraints/sram_controller.sdc
# Consolidated constraints for all modules: CDC, Clock Gating, Falling-Edge Sampling

# ============================================================================
# Clock Definitions (Story 7.3)
# ============================================================================

# AHB Clock (Controller Clock Domain)
create_clock -name hclk -period 25.0 [get_ports hclk]

# PMU Clock Domain
create_clock -name clk_pmu -period 10.0 [get_ports clk_pmu]

# Controller Clock (same as AHB clock in this design)
# Note: In top-level, clk_ctrl = hclk
set clk_ctrl [get_clocks hclk]

# ============================================================================
# Story 2.2: Clock Gating Timing Constraints
# ============================================================================

# Clock Gating Timing Constraints
# Setup time constraint for enable signal to negative-edge latch
set_clock_gating_check -setup 0.1 -hold 0.1 [get_cells *enable_latch*]

# Hold time constraint for enable signal to negative-edge latch
# The latch captures enable on negative edge, so setup/hold are relative to falling edge
set_clock_gating_check -setup 0.1 -hold 0.1 -rise [get_cells *enable_latch*]

# Clock gating timing validation for clk_gated output
# Ensure gated clock meets minimum pulse width (0.8955 ns) - matches SRAM requirement
set_min_pulse_width -high 0.8955 [get_clocks *clk_gated*]
set_min_pulse_width -low 0.8955 [get_clocks *clk_gated*]

# Setup/hold margins for all flip-flops (NFR2: > 0.1 ns margins)
set_clock_uncertainty -setup 0.1 [get_clocks hclk]
set_clock_uncertainty -hold 0.1 [get_clocks hclk]
set_clock_uncertainty -setup 0.1 [get_clocks clk_pmu]
set_clock_uncertainty -hold 0.1 [get_clocks clk_pmu]

# ============================================================================
# Story 1.2: CDC Constraints (PMU Synchronizer)
# ============================================================================

# False path: PMU clock domain to controller clock domain (before synchronizer)
set_false_path -from [get_clocks clk_pmu] -to [get_registers {*pwr_save_req_meta* *pwr_restore_req_meta*}]

# Alternative constraint: set_max_delay for synthesis tools that prefer max_delay
set_max_delay -from [get_clocks clk_pmu] -to [get_registers {*pwr_save_req_meta* *pwr_restore_req_meta*}] -datapath_only 10.0

# Multicycle path: Synchronizer stages (allow 2 cycles for metastability resolution)
# pwr_save_req synchronizer
set_multicycle_path -setup 2 -from [get_registers *pwr_save_req_meta*] -to [get_registers *pwr_save_req_sync1*]
set_multicycle_path -hold 1 -from [get_registers *pwr_save_req_meta*] -to [get_registers *pwr_save_req_sync1*]

# pwr_restore_req synchronizer
set_multicycle_path -setup 2 -from [get_registers *pwr_restore_req_meta*] -to [get_registers *pwr_restore_req_sync1*]
set_multicycle_path -hold 1 -from [get_registers *pwr_restore_req_meta*] -to [get_registers *pwr_restore_req_sync1*]

# ============================================================================
# Story 5.5: Falling-Edge Sampling Constraints (NFR3, NFR4)
# ============================================================================

# Clock definition for AHB clock (if not already defined)
create_clock -name hclk -period 25.0 [get_ports hclk]

# Falling-Edge Sampling Path: SRAM dout0 to hrdata_falling
# SRAM outputs change on falling edge of clk0 (0.484 ns worst-case delay)
# Capture on falling edge provides half-cycle margin (12.5 ns)
# Path: sram_dout0[31:0] -> hrdata_falling[31:0] (falling-edge capture)

# Create generated clock for falling edge
create_generated_clock -name hclk_falling \
    -source [get_ports hclk] \
    -divide_by 1 \
    -invert \
    [get_pins {*/hrdata_falling_reg[*]/CLK}]

# Falling-edge capture: Setup/hold relative to falling edge
# Setup: Data must be stable before falling edge (account for 0.484 ns delay)
set_max_delay -from [get_ports sram_dout0] \
    -to [get_registers hrdata_falling] \
    -datapath_only 12.5

# Hold: Data must remain stable after falling edge
set_min_delay -from [get_ports sram_dout0] \
    -to [get_registers hrdata_falling] \
    -datapath_only 0.484

# Half-cycle margin validation: Falling-edge to rising-edge path
# Path: hrdata_falling -> hrdata_reg (rising-edge register)
# This path has full cycle (25.0 ns) minus half-cycle margin (12.5 ns) = 12.5 ns available
set_max_delay -from [get_registers hrdata_falling] \
    -to [get_registers hrdata_reg] \
    -datapath_only 12.5

# Worst-case delay accounting: Ensure 0.484 ns SRAM delay is accounted for
# Add timing margin to account for SRAM propagation delay
set_timing_derate -early 0.95 [get_cells -hierarchical -filter "@is_sequential==true"]
set_timing_derate -late 1.05 [get_cells -hierarchical -filter "@is_sequential==true"]

# Falling-edge sampling: Verify half-cycle margin is sufficient
# Half-cycle = 12.5 ns, worst-case delay = 0.484 ns
# Margin = 12.5 ns - 0.484 ns = 12.01 ns (sufficient for 130nm routing parasitics)

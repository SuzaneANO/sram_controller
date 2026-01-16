# SDC Timing Constraints for PMU Synchronizer CDC Paths
# Story 1.2: Create SDC Constraints for PMU Synchronizer
# File: constraints/sram_controller_cdc.sdc

# Clock Definitions
create_clock -name clk_pmu -period 10.0 [get_ports clk_pmu]
create_clock -name clk_ctrl -period 25.0 [get_ports clk_ctrl]

# False path: PMU clock domain to controller clock domain (before synchronizer)
set_false_path -from [get_clocks clk_pmu] -to [get_registers {pwr_save_req_meta pwr_restore_req_meta}]

# Alternative constraint: set_max_delay for synthesis tools that prefer max_delay
# This provides redundancy and ensures CDC paths are properly constrained
set_max_delay -from [get_clocks clk_pmu] -to [get_registers {pwr_save_req_meta pwr_restore_req_meta}] -datapath_only 10.0

# Multicycle path: Synchronizer stages (allow 2 cycles for metastability resolution)
# pwr_save_req synchronizer
set_multicycle_path -setup 2 -from [get_registers pwr_save_req_meta] -to [get_registers pwr_save_req_sync1]
set_multicycle_path -hold 1 -from [get_registers pwr_save_req_meta] -to [get_registers pwr_save_req_sync1]

# pwr_restore_req synchronizer
set_multicycle_path -setup 2 -from [get_registers pwr_restore_req_meta] -to [get_registers pwr_restore_req_sync1]
set_multicycle_path -hold 1 -from [get_registers pwr_restore_req_meta] -to [get_registers pwr_restore_req_sync1]

# Synchronized outputs: Normal timing (after 3 stages)
# No special constraints needed - treated as normal synchronous signals

# SRAM Controller - OpenLane Physical Design

A power-aware SRAM controller with AHB-Lite interface, implemented in SystemVerilog and synthesized using the OpenLane flow for the Sky130 process.

## Overview

This design implements a complete SRAM controller with the following features:

- **AHB-Lite Protocol Interface**: AMBA-compliant slave interface with 32-bit data path
- **Power Management**: Dual power domains with clock gating and power state machine
- **Parity Protection**: Error detection for data integrity
- **SRAM Integration**: Direct interface to Sky130 SRAM macro (1KB, 32x256)
- **CDC Handling**: Proper clock domain crossing for PMU interface

## Design Architecture

### Top-Level Module
- **`sram_controller.sv`**: Integrates all sub-modules and SRAM macro

### Core Modules

1. **PMU Synchronizer** (`sram_controller_pmu_sync.sv`)
   - 3-stage synchronizer for clock domain crossing
   - Handles power save/restore requests from PMU domain

2. **Clock Gating ICG** (`sram_controller_cgic.sv`)
   - Negative-edge latch-based clock gating
   - Enables clock gating during sleep states

3. **Wakeup Timer** (`sram_controller_wakeup_timer.sv`)
   - Configurable wakeup delay timer
   - Ensures stable power restoration

4. **Power State Machine** (`sram_controller_fsm.sv`)
   - 3-state FSM: ACTIVE, SLEEP, WAKEUP
   - Controls isolation, power gating, and clock gating

5. **AHB-Lite Interface** (`sram_controller_ahb_lite.sv`)
   - Full AHB-Lite slave implementation
   - Falling-edge sampling for SRAM read data
   - Parity error detection

6. **Parity Logic** (`sram_controller_parity.sv`, `sram_controller_parity_storage.sv`)
   - Even parity generation and checking
   - Parity storage for write operations

## Design Steps

### 1. RTL Design & Verification
- Designed all modules in SystemVerilog
- Verified functionality with simulation
- Ensured proper clock domain crossing

### 2. OpenLane Configuration
- Created `config.json` with design parameters:
  - Clock period: 25.0 ns (40 MHz)
  - Die area: 1500x1500 microns
  - Placement density: 0.25
  - Dual power domains (vccd1, vccd2)

### 3. Timing Constraints
- **`constraints/sram_controller.sdc`**: Main timing constraints
  - Clock definitions (hclk, clk_pmu)
  - Clock gating constraints
  - CDC false paths and multicycle paths
  - Falling-edge sampling constraints (0.484 ns SRAM delay)
  
- **`constraints/sram_controller_cdc.sdc`**: CDC-specific constraints
  - PMU synchronizer timing
  - Metastability resolution paths

### 4. Macro Placement
- **`macro_placement.cfg`**: Manual SRAM macro placement
  - Positioned at (100, 500) with North orientation
  - Left space for controller logic

### 5. OpenLane Flow Execution
```bash
cd /home/adamsbane/OpenLane
./flow.tcl -design sram_controller -tag sram_controller_run
```

**Flow Stages:**
1. **Synthesis** - Yosys RTL synthesis
2. **Floorplanning** - Die area and macro placement
3. **Placement** - Standard cell placement
4. **Clock Tree Synthesis** - Clock distribution network
5. **Routing** - Signal routing with congestion handling
6. **Signoff** - STA, DRC, LVS verification

### 6. Timing Closure
- Verified worst-case slack > 1.0 ns
- Confirmed falling-edge sampling paths meet timing
- Validated CDC paths with zero violations
- Ensured clock gating meets minimum pulse width (0.8955 ns)

### 7. Physical Verification
- DRC: All violations resolved
- LVS: Layout vs. schematic matching verified
- Hold violations: Addressed with buffer insertion

## Key Design Decisions

### Power Management
- **Dual Power Domains**: Controller (vccd1) always-on, SRAM (vccd2) gated
- **Clock Gating**: Reduces dynamic power during sleep
- **Isolation Cells**: Prevent floating signals during power gating

### Timing Considerations
- **Falling-Edge Sampling**: SRAM outputs change on falling edge (0.484 ns delay)
- **Half-Cycle Margin**: 12.5 ns available for falling-edge to rising-edge capture
- **CDC Synchronization**: 3-stage synchronizer for PMU signals

### SRAM Interface
- **Falling-Edge Clock**: SRAM macro uses falling-edge triggered clock
- **Write Masking**: 4-byte write mask for partial writes
- **Address Mapping**: 8-bit address for 256-word SRAM

## File Structure

```
sram_controller_github/
├── README.md                    # This file
├── config.json                  # OpenLane configuration
├── macro_placement.cfg          # SRAM macro placement
├── src/                         # RTL source files
│   ├── sram_controller.sv              # Top-level module
│   ├── sram_controller_pmu_sync.sv     # PMU synchronizer
│   ├── sram_controller_cgic.sv          # Clock gating ICG
│   ├── sram_controller_wakeup_timer.sv # Wakeup timer
│   ├── sram_controller_fsm.sv          # Power state machine
│   ├── sram_controller_ahb_lite.sv     # AHB-Lite interface
│   ├── sram_controller_parity.sv       # Parity logic
│   ├── sram_controller_parity_storage.sv # Parity storage
│   └── sky130_sram_1kbyte_1rw1r_32x256_8.bb.v # SRAM blackbox
└── constraints/                 # SDC timing constraints
    ├── sram_controller.sdc      # Main timing constraints
    └── sram_controller_cdc.sdc # CDC constraints
```

## Results

### Physical Design Metrics
- **Technology**: Sky130 (130nm)
- **Die Area**: 1500 x 1500 microns
- **Clock Frequency**: 40 MHz (25.0 ns period)
- **Power Domains**: 2 (vccd1 controller, vccd2 SRAM)

### Timing Results
- **Worst-Case Slack**: > 1.0 ns
- **Falling-Edge Paths**: Properly constrained with 0.484 ns delay
- **CDC Paths**: Zero violations
- **Clock Gating**: 0.8955 ns minimum pulse width

### Physical Verification
- **DRC**: All violations resolved
- **LVS**: Layout matches schematic
- **Hold Violations**: Addressed and resolved

### GDSII Layout

*Add GDSII layout screenshot here:*
- Open the final GDSII file in KLayout: `designs/sram_controller/runs/*/results/final/gds/sram_controller.gds`
- Take a screenshot showing the complete layout with SRAM macro and controller logic
- Save as `gdsii_layout.png` in this directory

## Running the Design

### Prerequisites
- OpenLane environment with Sky130 PDK
- SRAM macro files (LEF, GDS, LIB) in PDK path

### Execute Flow
```bash
cd /path/to/OpenLane
./flow.tcl -design sram_controller -tag run_01
```

### Verify Results
```bash
# Check timing reports
cat designs/sram_controller/runs/run_01/reports/signoff/25-rcx_sta.rpt | grep -i "worst.*slack"

# View GDSII in KLayout
klayout designs/sram_controller/runs/run_01/results/final/gds/sram_controller.gds
```

## References

- **AMBA AHB-Lite Specification**: ARM AMBA Protocol Specification
- **Sky130 PDK**: Open-source 130nm process design kit
- **OpenLane**: Open-source digital ASIC flow

## License

This design is provided as-is for educational and research purposes.

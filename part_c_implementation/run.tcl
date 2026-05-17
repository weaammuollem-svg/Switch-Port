########################################################################
### 1. GLOBAL SETTINGS & ENVIRONMENT SETUP
########################################################################
# Configure multi-threading to accelerate compute-intensive tasks
set_host_options -max_cores 4

# Define technology file for physical layer constraints and metal stack info
set TECH_FILE "/data/synopsys/lib/saed32nm/ref/tech/saed32nm_1p9m.tf"

# Set Logical Library paths (NLDM) for logic synthesis and timing analysis
set_app_var target_library "/data/synopsys/lib/saed32nm/ref/db_nldm/saed32rvt_ff0p85v25c.db"
set_app_var link_library   "* /data/synopsys/lib/saed32nm/ref/db_nldm/saed32rvt_ff0p85v25c.db"

########################################################################
### 2. DESIGN ELABORATION & PHYSICAL LIBRARY SETUP
########################################################################
# Purge existing work library to ensure a clean workspace
catch {close_lib -purge switch.dlib} 
if {[file exists switch.dlib]} { file delete -force switch.dlib }

# Create a new design library and link reference NDM (New Data Model) files
create_lib -technology $TECH_FILE -ref_libs { \
    /data/synopsys/lib/saed32nm/ref/CLIBs/saed32_hvt.ndm \
    /data/synopsys/lib/saed32nm/ref/CLIBs/saed32_lvt.ndm \
    /data/synopsys/lib/saed32nm/ref/CLIBs/saed32_rvt.ndm \
} switch.dlib

open_lib switch.dlib

# Load TLUPlus files for RC parasitic estimation at different process corners
read_parasitic_tech -tlu /data/synopsys/lib/saed32nm/ref/tech/saed32nm_1p9m_Cmax.lv.tluplus -name Cmax
read_parasitic_tech -tlu /data/synopsys/lib/saed32nm/ref/tech/saed32nm_1p9m_Cmin.lv.tluplus -name Cmin

# Analyze HDL and elaborate the design hierarchy
analyze -format sverilog {switch_port.sv switch_4port.sv}
elaborate switch_4port
set_top_module switch_4port

########################################################################
### 3. MCMM (MULTI-CORNER MULTI-MODE) & DESIGN CONSTRAINTS
########################################################################
# Reset previous scenario configurations
remove_corners -all
remove_modes -all
remove_scenarios -all

# Define Best-Case (Fast) and Worst-Case (Slow) corners for PVT analysis
create_corner Fast
create_corner Slow
set_parasitics_parameters -early_spec Cmin -late_spec Cmin -corners {Fast}
set_parasitics_parameters -early_spec Cmax -late_spec Cmax -corners {Slow}

# Initialize Scenario for Functional Mode at both process corners
create_mode FUNC
create_scenario -mode FUNC -corner Fast -name FUNC_Fast
create_scenario -mode FUNC -corner Slow -name FUNC_Slow

# Apply SDC (Synopsys Design Constraints) for timing, clock, and IO
current_mode FUNC
source ./fifo.sdc

# Define initial floorplan estimates (70% utilization, square aspect ratio)
set_auto_floorplan_constraints -core_utilization 0.7 -side_ratio {1 1} -core_offset 2

########################################################################
### 4. RUN A: BASELINE SYNTHESIS (NO CLOCK GATING)
########################################################################
# Execute synthesis and initial physical optimization without Power Optimization
compile_fusion -to final_opto

# Export Baseline Reports for Comparative Analysis
report_power  > power_no_cg.txt [cite: 28]
report_area   > area_no_cg.txt
report_timing > timing_no_cg.txt
report_qor    > qor_no_cg.txt

# Snapshot baseline design state
save_block -as switch/baseline_no_cg

########################################################################
### 5. RUN B: POWER-OPTIMIZED SYNTHESIS (INTEGRATED CLOCK GATING)
########################################################################
# Refresh SDC constraints before secondary optimization run
remove_sdc
source ./fifo.sdc

# Trigger Fusion compilation with automatic Integrated Clock Gating (ICG) insertion
# This targets reduction in dynamic switching power by disabling idle clock branches
compile_fusion -to final_opto -gate_clock

# Export Optimized Reports to quantify Clock Gating (CG) impact
report_power        > power_with_cg.txt [cite: 1]
report_area         > area_with_cg.txt
report_timing       > timing_with_cg.txt
report_qor          > qor_with_cg.txt
report_clock_gating > clock_gating_details.txt

# Save final optimized database
save_block -as switch/final_gated_design

########################################################################
### 6. SIGNOFF DELIVERABLES & POST-SYNTHESIS EXPORTS
########################################################################
# 1. Export Gate-Level Netlist (GLN) for functional verification
write_verilog switch_4port_netlist.v

# 2. Export Standard Delay Format (SDF) for timing-accurate gate-level simulation
write_sdf switch_4port.sdf

# 3. Final Timing Slack Analysis (Fmax evaluation)
report_timing -max_paths 10 > final_slack_report.txt


echo "SUCCESS: Signoff netlist and parasitics generated."
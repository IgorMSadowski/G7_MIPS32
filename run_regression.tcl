# ==============================================================================
# REGRESSION TEST SCRIPT
# ==============================================================================
# HOW TO USE:
#   1. Open the Vivado project (G7_MIPS32.xpr)
#   2. Open the Tcl Console at the bottom of the Vivado window
#   3. Type the following command and press Enter:
#      source run_regression.tcl
#
# REQUIREMENTS:
#   - The script must be in the same folder as the Vivado .xpr file.
#   - All testbenches (tb_alu, tb_regfile, tb_control_unit, tb_bdu, tb_soc)
#     must be added to "Simulation Sources" in the Vivado project.
# ==============================================================================

proc run_one {tb_name} {
    puts "\n============================================================"
    puts "Running $tb_name"
    puts "============================================================"
    set_property top $tb_name [get_filesets sim_1]
    reset_simulation -simset sim_1
    launch_simulation
    run all
    close_simulation
}

set tbs {tb_alu tb_regfile tb_control_unit tb_bdu tb_soc}
foreach tb $tbs { run_one $tb }
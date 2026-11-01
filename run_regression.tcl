# ==============================================================================
# REGRESSION TEST SCRIPT
# ==============================================================================
# Open G7_MIPS32.xpr, save/close any active simulation, then run:
# source {/home/igor/Documents/Vivado_Projects/G7_MIPS32/run_regression.tcl}
# Uses the project's existing ROM configuration; does not select a .mem file.
# A failed test is reported in the summary and makes this script return an error.
# ==============================================================================

proc run_one {tb_name simset} {
    puts "\nRunning $tb_name"
    set_property top $tb_name $simset
    update_compile_order -fileset $simset
    launch_simulation -simset $simset -mode behavioral
    run all
    set errors [get_value -radix unsigned /${tb_name}/errors]
    if {![string is integer -strict $errors]} {
        error "$tb_name: error counter is not a known integer: $errors"
    }
    if {$errors != 0} {
        error "$tb_name: $errors failed checks (see simulation messages)"
    }
}

load_features simulator
if {[current_sim -quiet] ne ""} {
    error "Save your waveform configuration and close the active simulation first."
}

set regression_dir [file dirname [file normalize [info script]]]
set pause_tb [file join $regression_dir G7_MIPS32.srcs sim_1 new tb_cpu_memory.v]
if {[llength [get_files -quiet $pause_tb]] == 0} {
    add_files -fileset sim_1 -norecurse $pause_tb
}

set regression_simset [get_filesets sim_1]
set regression_old_top [get_property top $regression_simset]
set regression_old_runtime [get_property xsim.simulate.runtime $regression_simset]
set_property xsim.simulate.runtime 0ns $regression_simset
set regression_results {}
set regression_failed 0

foreach tb {tb_alu tb_regfile tb_control_unit tb_bdu tb_cpu_memory tb_soc} {
    set failed [catch {run_one $tb $regression_simset} message]
    # Avoid discarding unsaved waveform changes with close_sim -force.
    if {[catch {close_sim} close_message]} {
        if {!$failed} { set message $close_message }
        set failed 1
    }
    if {$failed} {
        incr regression_failed
        lappend regression_results "$tb: FAIL - $message"
    } else {
        lappend regression_results "$tb: PASS"
    }
}

set_property top $regression_old_top $regression_simset
set_property xsim.simulate.runtime $regression_old_runtime $regression_simset
puts "\nRegression summary"
foreach result $regression_results { puts $result }
if {$regression_failed != 0} {
    error "$regression_failed testbench(es) failed. See the summary and simulation messages."
}
puts "PASS: all testbenches passed."

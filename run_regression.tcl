# ==============================================================================
# REGRESSION TEST SCRIPT
# ==============================================================================
# Open G7_MIPS32.xpr, save/close any active simulation, then run:
# source {/home/igor/Documents/Vivado_Projects/G7_MIPS32/run_regression.tcl}
# Uses test ROMs through module parameters; does not change project ROM settings.
# Uses all existing component simulation sets and creates test sets when needed.
# A failed test is reported in the summary and makes this script return an error.
# ==============================================================================

proc run_one {tb_name simset} {
    set fileset [get_filesets -quiet $simset]
    if {[llength $fileset] != 1} {
        error "Simulation set '$simset' is missing; expected top '$tb_name'."
    }
    set old_top [get_property top $fileset]
    set old_runtime [get_property xsim.simulate.runtime $fileset]
    puts "\nRunning $tb_name in simulation set $simset"
    set failed [catch {
        current_fileset -simset $fileset
        set_property top $tb_name $fileset
        set_property xsim.simulate.runtime 0ns $fileset
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
    } message options]

    # Preserve source-set settings even if compilation or a test fails.
    set close_failed 0
    if {[current_sim -quiet] ne ""} {
        set close_failed [catch {close_sim} close_message]
    }
    set_property top $old_top $fileset
    set_property xsim.simulate.runtime $old_runtime $fileset
    if {$failed} { return -options $options $message }
    if {$close_failed} { error $close_message }
}

load_features simulator
if {[current_sim -quiet] ne ""} {
    error "Save your waveform configuration and close the active simulation first."
}

set regression_old_active [current_fileset -simset]
set regression_dir [file dirname [file normalize [info script]]]
set component_set [get_filesets -quiet component_tests]
if {[llength $component_set] == 0} {
    create_fileset -simset component_tests
    set component_set [get_filesets component_tests]
    set_property SOURCE_SET sources_1 $component_set
    set_property top tb_memories $component_set
}
set component_dir [file join $regression_dir G7_MIPS32.srcs sim_1 new]
foreach tb_name {
    tb_memories.v
} {
    set tb_path [file join $component_dir $tb_name]
    if {![file exists $tb_path]} {
        error "Component testbench not found: $tb_path"
    }
    if {[lsearch -exact [get_files -quiet -of_objects $component_set] $tb_path] < 0} {
        add_files -fileset component_tests -norecurse $tb_path
    }
}

# Register the standalone datapath test.
set datapath_tb [file join $regression_dir G7_MIPS32.srcs sim_1 new tb_datapath.v]
if {![file exists $datapath_tb]} {
    error "Datapath testbench not found: $datapath_tb"
}
set datapath_set [get_filesets -quiet datapath]
if {[llength $datapath_set] == 0} {
    create_fileset -simset datapath
    set datapath_set [get_filesets datapath]
    set_property SOURCE_SET sources_1 $datapath_set
    set_property top tb_datapath $datapath_set
}
if {[lsearch -exact [get_files -quiet -of_objects $datapath_set] $datapath_tb] < 0} {
    add_files -fileset datapath -norecurse $datapath_tb
}
set datapath_wave [file join $regression_dir tb_datapath_behav.wcfg]
if {[file exists $datapath_wave] &&
    [lsearch -exact [get_files -quiet -of_objects $datapath_set] $datapath_wave] < 0} {
    add_files -fileset datapath -norecurse $datapath_wave
}

set regression_results {}
set regression_failed 0
foreach {simset tb} {
    alu          tb_alu
    regfile      tb_regfile
    control_unit tb_control_unit
    bdu          tb_bdu
    component_tests tb_memories
    datapath     tb_datapath
    data_bus     tb_data_bus
    soc          tb_soc
} {
    if {[catch {run_one $tb $simset} message]} {
        incr regression_failed
        lappend regression_results "$simset / $tb: FAIL - $message"
    } else {
        lappend regression_results "$simset / $tb: PASS"
    }
}
if {[llength $regression_old_active] != 0} {
    current_fileset -simset $regression_old_active
}
puts "\nRegression summary"
foreach result $regression_results { puts $result }
if {$regression_failed != 0} {
    error "$regression_failed testbench(es) failed. See the summary and simulation messages."
}
puts "PASS: all testbenches passed."

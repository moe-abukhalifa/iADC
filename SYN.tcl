remove_design -all

#------------------------------------------------------
#	Define name rules
#------------------------------------------------------
set default_name_rules sverilog
define_name_rules sverilog -max_length   32
set change_names_dont_change_bus_members true

source ./scripts/variables.tcl

read_file -format ddc $DDC_ELAB_FILE

current_design $DESIGN_NAME
check_design

source ./scripts/scan_config.tcl

source ./scripts/constraints.tcl

#------------------------------------------------------
#	Map design to gates w/o scan insertion
#------------------------------------------------------
if { [info exists SCAN_CONFIG] && $SCAN_CONFIG == true} {
   compile_ultra -scan	> ./log/compile.scan.log
} else {
   compile_ultra	> ./log/compile.log
}

#uniquify
#link

if { [info exists SCAN_CONFIG] && $SCAN_CONFIG == true} {

   set_scan_state test_ready
   set_dft_configuration -fix_clock enable -fix_reset enable

   create_test_protocol          > $REPORT_PATH/create_test_protocol.log
   preview_dft -show all         > $REPORT_PATH/preview_dft.log
   preview_dft -test_points all >> $REPORT_PATH/preview_dft.log
   dft_drc -pre_dft -verbose     > $REPORT_PATH/dft_drc_pre.log

   insert_dft                    > $REPORT_PATH/insert_dft.log

   compile_ultra -inc            > ./log/compile_inc.log

   dft_drc -verbose -coverage_estimate             > $REPORT_PATH/dft_drc.log
   report_dft -scan                                > $REPORT_PATH/report_dft.log
   report_dft_signal -view existing_dft           >> $REPORT_PATH/report_dft.log
   report_scan_configuration                       > $REPORT_PATH/report_scan.log
   report_scan_path -view existing_dft -chain all >> $REPORT_PATH/report_scan.log
   report_scan_path -view existing_dft -cell all  >> $REPORT_PATH/report_scan.log

}

#----------------------------------------------------------------------------------------
#       Save mapped design
#----------------------------------------------------------------------------------------
if { [info exists SCAN_CONFIG] && $SCAN_CONFIG == true} {
   write -hierarchy -format ddc -output $DDC_MAPPED_SCAN_FILE
} else {
   write -hierarchy -format ddc -output $DDC_MAPPED_FILE
}

#----------------------------------------------------------------------------------------
#	Generate reports
#----------------------------------------------------------------------------------------
if { [info exists SCAN_CONFIG] && $SCAN_CONFIG == true} {
   report_area -nosplit				> $RPT_AREA_SCAN_FILE
   report_timing -path full -delay max -nworst 1 -max_paths 1 -significant_digits 2 \
                 -nosplit -sort_by group	> ${RPT_TIMING_MAX_SCAN_FILE}
#   report_timing -path full -delay min -nworst 1 -max_paths 1 -significant_digits 2 \
                 -nosplit -sort_by group	> ${RPT_TIMING_MIN_SCAN_FILE}
   report_resources -nosplit -hierarchy		> $RPT_RESOURCES_SCAN_FILE
   report_reference -nosplit			> $RPT_REFERENCES_SCAN_FILE
   report_cell -nosplit				> $RPT_CELLS_SCAN_FILE
} else {
   report_area -nosplit				> $RPT_AREA_FILE
   report_timing -path full -delay max -nworst 1 -max_paths 1 -significant_digits 2 \
                 -nosplit -sort_by group	> ${RPT_TIMING_MAX_FILE}
#   report_timing -path full -delay min -nworst 1 -max_paths 1 -significant_digits 2 \
                 -nosplit -sort_by group	> ${RPT_TIMING_MIN_FILE}
   report_resources -nosplit -hierarchy		> $RPT_RESOURCES_FILE
   report_reference -nosplit			> $RPT_REFERENCES_FILE
   report_cell -nosplit				> $RPT_CELLS_FILE
}

#----------------------------------------------------------------------------------------
#	Generate VERILOG netlist
#	
#	Note: The design is reloaded from scratch to avoid potential
#	      naming problems when using the netlist for P&R
#----------------------------------------------------------------------------------------
remove_design -all

if { [info exists SCAN_CONFIG] && $SCAN_CONFIG == true} {
   read_file -format ddc $DDC_MAPPED_SCAN_FILE
   change_names -rule verilog -hierarchy -verbose
   write -format verilog -hierarchy -output $NETLIST_SCAN_FILE
   write_scan_def -output $SCANDEF_FILE
} else {
   read_file -format ddc $DDC_MAPPED_FILE
   change_names -rule verilog -hierarchy -verbose
   write -format verilog -hierarchy -output $NETLIST_FILE
}

#----------------------------------------------------------------------------------------
#	Generate SDF data for Verilog and system constraints
#----------------------------------------------------------------------------------------
#set_operating_conditions $MAX_CONDITION -library "c35_CORELIB.db:c35_CORELIB"
#set_timing_ranges [list "SLOW_RANGE"] -library "c35_CORELIB.db:c35_CORELIB"
#update_timing

if { [info exists SCAN_CONFIG] && $SCAN_CONFIG == true} {
   write_sdf -version 2.1 $SDF_SCAN_FILE
   write_sdc -nosplit $SDC_SCAN_FILE
   write_test_protocol -out $STIL_FILE
} else {
   write_sdf -version 2.1 $SDF_FILE
   write_sdc -nosplit $SDC_FILE
}

#set_operating_conditions $MIN_CONDITION -library "c35_CORELIB.db:c35_CORELIB"
#set_timing_ranges [list "FAST_RANGE"] -library "c35_CORELIB.db:c35_CORELIB"
#update_timing


#if { [info exists SCAN_CONFIG] && $SCAN_CONFIG == true} {
#   write_sdf -version 2.1 $SDF_MIN_SCAN_FILE
#} else {
#   write_sdf -version 2.1 $SDF_MIN_FILE
#}

exit

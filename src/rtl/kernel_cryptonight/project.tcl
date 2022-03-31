set kernel_dir          [lindex $::argv 0]
set path_to_tmp_project [lindex $::argv 1]
set path_to_packaged    [lindex $::argv 2]

create_project -force kernel_pack $path_to_tmp_project

set source_list [regexp -all -inline {\S+} [read [open "${kernel_dir}/sources" "r"]]]
foreach line ${source_list} {
  lappend source_files [file normalize $line]
}
add_files -norecurse $source_files

source -notrace "${kernel_dir}/ip.tcl"

################################################################################

source -notrace "${kernel_dir}/bd.tcl"
source -notrace "${kernel_dir}/tb/bd.tcl"

################################################################################

set_property top cryptonight [get_filesets sources_1]
set_property top tb_cryptonight_logic [get_filesets sim_1]

################################################################################

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

################################################################################

ipx::package_project -root_dir $path_to_packaged -vendor xilinx.com -library RTLKernel -taxonomy /KernelIP -import_files -set_current false
ipx::unload_core $path_to_packaged/component.xml
ipx::edit_ip_in_project -upgrade true -name tmp_edit_project -directory $path_to_packaged $path_to_packaged/component.xml

set_property core_revision 2 [ipx::current_core]
foreach up [ipx::get_user_parameters] {
  ipx::remove_user_parameter [get_property NAME $up] [ipx::current_core]
}

set_property sdx_kernel true [ipx::current_core]
set_property sdx_kernel_type rtl [ipx::current_core]
# set_property ipi_drc {ignore_freq_hz true} [ipx::current_core]
# set_property vitis_drc {ctrl_protocol ap_ctrl_hs} [ipx::current_core]

ipx::create_xgui_files [ipx::current_core]
# ipx::infer_bus_interface ap_clk_2   xilinx.com:signal:clock_rtl:1.0 [ipx::current_core]
# ipx::infer_bus_interface ap_rst_n_2 xilinx.com:signal:reset_rtl:1.0 [ipx::current_core]

ipx::associate_bus_interfaces -busif m00_axi       -clock ap_clk [ipx::current_core]
ipx::associate_bus_interfaces -busif s_axi_control -clock ap_clk [ipx::current_core]

set_property xpm_libraries {XPM_CDC XPM_MEMORY XPM_FIFO} [ipx::current_core]
set_property supported_families { } [ipx::current_core]
set_property auto_family_support_level level_2 [ipx::current_core]

ipx::update_checksums [ipx::current_core]
ipx::save_core [ipx::current_core]

close_project -delete
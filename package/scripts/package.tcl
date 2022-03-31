if { $::argc != 5 } {
  puts "ERROR: package.tcl requires 5 arguments:\n"
  puts "<kernel_name> <target> <platform> <build_dir> <temp_dir>\n"
  exit
}

set kernel_name [lindex $::argv 0]
set target      [lindex $::argv 1]
set platform    [lindex $::argv 2]
set build_dir   [lindex $::argv 3]
set temp_dir    [lindex $::argv 4]

set project_dir "[exec pwd]"
set kernel_dir  "${project_dir}/src/rtl/kernel_${kernel_name}"
set xo_path     "${build_dir}/${kernel_name}.xo"

set path_to_tmp_project "${temp_dir}/_${kernel_name}"
set path_to_packaged    "${temp_dir}/${kernel_name}"

set ::argv [list ${kernel_dir} ${path_to_tmp_project} ${path_to_packaged}]
source "$kernel_dir/project.tcl"

package_xo                                \
  -xo_path      ${xo_path}                \
  -kernel_name  ${kernel_name}            \
  -ip_directory ${path_to_packaged}       \
  -kernel_xml   ${kernel_dir}/kernel.xml  \
  -verbose                                \
  -force
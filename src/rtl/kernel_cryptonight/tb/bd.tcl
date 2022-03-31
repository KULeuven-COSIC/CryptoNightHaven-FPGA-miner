
################################################################
# This is a generated script based on design: cryptonight_logic_bd_tb
#
# Though there are limitations about the generated script,
# the main purpose of this utility is to make learning
# IP Integrator Tcl commands easier.
################################################################

namespace eval _tcl {
proc get_script_folder {} {
   set script_path [file normalize [info script]]
   set script_folder [file dirname $script_path]
   return $script_folder
}
}
variable script_folder
set script_folder [_tcl::get_script_folder]

################################################################
# Check if script is running in correct Vivado version.
################################################################
set scripts_vivado_version 2021.1
set current_vivado_version [version -short]

if { [string first $scripts_vivado_version $current_vivado_version] == -1 } {
   puts ""
   catch {common::send_gid_msg -ssname BD::TCL -id 2041 -severity "ERROR" "This script was generated using Vivado <$scripts_vivado_version> and is being run in <$current_vivado_version> of Vivado. Please run the script in Vivado <$scripts_vivado_version> then open the design in Vivado <$current_vivado_version>. Upgrade the design by running \"Tools => Report => Report IP Status...\", then run write_bd_tcl to create an updated script."}

   return 1
}

################################################################
# START
################################################################

# To test this script, run the following commands from Vivado Tcl console:
# source cryptonight_logic_bd_tb_script.tcl


# The design that will be created by this Tcl script contains the following 
# module references:
# cryptonight_logic

# Please add the sources of those modules before sourcing this Tcl script.

# If there is no project opened, this script will create a
# project, but make sure you do not have an existing project
# <./myproj/project_1.xpr> in the current working folder.

set list_projs [get_projects -quiet]
if { $list_projs eq "" } {
   create_project project_1 myproj -part xc7vx485tffg1157-1
}


# CHANGE DESIGN NAME HERE
variable design_name
set design_name cryptonight_logic_bd_tb

# If you do not already have an existing IP Integrator design open,
# you can create a design using the following command:
#    create_bd_design $design_name

# Creating design if needed
set errMsg ""
set nRet 0

set cur_design [current_bd_design -quiet]
set list_cells [get_bd_cells -quiet]

if { ${design_name} eq "" } {
   # USE CASES:
   #    1) Design_name not set

   set errMsg "Please set the variable <design_name> to a non-empty value."
   set nRet 1

} elseif { ${cur_design} ne "" && ${list_cells} eq "" } {
   # USE CASES:
   #    2): Current design opened AND is empty AND names same.
   #    3): Current design opened AND is empty AND names diff; design_name NOT in project.
   #    4): Current design opened AND is empty AND names diff; design_name exists in project.

   if { $cur_design ne $design_name } {
      common::send_gid_msg -ssname BD::TCL -id 2001 -severity "INFO" "Changing value of <design_name> from <$design_name> to <$cur_design> since current design is empty."
      set design_name [get_property NAME $cur_design]
   }
   common::send_gid_msg -ssname BD::TCL -id 2002 -severity "INFO" "Constructing design in IPI design <$cur_design>..."

} elseif { ${cur_design} ne "" && $list_cells ne "" && $cur_design eq $design_name } {
   # USE CASES:
   #    5) Current design opened AND has components AND same names.

   set errMsg "Design <$design_name> already exists in your project, please set the variable <design_name> to another value."
   set nRet 1
} elseif { [get_files -quiet ${design_name}.bd] ne "" } {
   # USE CASES: 
   #    6) Current opened design, has components, but diff names, design_name exists in project.
   #    7) No opened design, design_name exists in project.

   set errMsg "Design <$design_name> already exists in your project, please set the variable <design_name> to another value."
   set nRet 2

} else {
   # USE CASES:
   #    8) No opened design, design_name not in project.
   #    9) Current opened design, has components, but diff names, design_name not in project.

   common::send_gid_msg -ssname BD::TCL -id 2003 -severity "INFO" "Currently there is no design <$design_name> in project, so creating one..."

   create_bd_design $design_name

   common::send_gid_msg -ssname BD::TCL -id 2004 -severity "INFO" "Making design <$design_name> as current_bd_design."
   current_bd_design $design_name

}

common::send_gid_msg -ssname BD::TCL -id 2005 -severity "INFO" "Currently the variable <design_name> is equal to \"$design_name\"."

if { $nRet != 0 } {
   catch {common::send_gid_msg -ssname BD::TCL -id 2006 -severity "ERROR" $errMsg}
   return $nRet
}

set bCheckIPsPassed 1
##################################################################
# CHECK IPs
##################################################################
set bCheckIPs 1
if { $bCheckIPs == 1 } {
   set list_check_ips "\ 
xilinx.com:ip:axi_bram_ctrl:4.1\
xilinx.com:ip:blk_mem_gen:8.4\
xilinx.com:ip:smartconnect:1.0\
"

   set list_ips_missing ""
   common::send_gid_msg -ssname BD::TCL -id 2011 -severity "INFO" "Checking if the following IPs exist in the project's IP catalog: $list_check_ips ."

   foreach ip_vlnv $list_check_ips {
      set ip_obj [get_ipdefs -all $ip_vlnv]
      if { $ip_obj eq "" } {
         lappend list_ips_missing $ip_vlnv
      }
   }

   if { $list_ips_missing ne "" } {
      catch {common::send_gid_msg -ssname BD::TCL -id 2012 -severity "ERROR" "The following IPs are not found in the IP Catalog:\n  $list_ips_missing\n\nResolution: Please add the repository containing the IP(s) to the project." }
      set bCheckIPsPassed 0
   }

}

##################################################################
# CHECK Modules
##################################################################
set bCheckModules 1
if { $bCheckModules == 1 } {
   set list_check_mods "\ 
cryptonight_logic\
"

   set list_mods_missing ""
   common::send_gid_msg -ssname BD::TCL -id 2020 -severity "INFO" "Checking if the following modules exist in the project's sources: $list_check_mods ."

   foreach mod_vlnv $list_check_mods {
      if { [can_resolve_reference $mod_vlnv] == 0 } {
         lappend list_mods_missing $mod_vlnv
      }
   }

   if { $list_mods_missing ne "" } {
      catch {common::send_gid_msg -ssname BD::TCL -id 2021 -severity "ERROR" "The following module(s) are not found in the project: $list_mods_missing" }
      common::send_gid_msg -ssname BD::TCL -id 2022 -severity "INFO" "Please add source files for the missing module(s) above."
      set bCheckIPsPassed 0
   }
}

if { $bCheckIPsPassed != 1 } {
  common::send_gid_msg -ssname BD::TCL -id 2023 -severity "WARNING" "Will not continue with creation of design due to the error(s) above."
  return 3
}

##################################################################
# DESIGN PROCs
##################################################################



# Procedure to create entire design; Provide argument to make
# procedure reusable. If parentCell is "", will use root.
proc create_root_design { parentCell } {

  variable script_folder
  variable design_name

  if { $parentCell eq "" } {
     set parentCell [get_bd_cells /]
  }

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2090 -severity "ERROR" "Unable to find parent cell <$parentCell>!"}
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2091 -severity "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
     return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj


  # Create interface ports

  # Create ports
  set axi_base_addr [ create_bd_port -dir I -from 63 -to 0 axi_base_addr ]
  set clk [ create_bd_port -dir I -type clk -freq_hz 100000000 clk ]
  set_property -dict [ list \
   CONFIG.ASSOCIATED_RESET {rstn:rstn} \
 ] $clk
  set clk_fast [ create_bd_port -dir I -type clk -freq_hz 400000000 clk_fast ]
  set clk_slow [ create_bd_port -dir I -type clk -freq_hz 100000000 clk_slow ]
  set_property -dict [ list \
   CONFIG.ASSOCIATED_RESET {} \
 ] $clk_slow
  set i_nonce [ create_bd_port -dir I -from 7 -to 0 i_nonce ]
  set i_state [ create_bd_port -dir I -from 1599 -to 0 i_state ]
  set i_valid [ create_bd_port -dir I i_valid ]
  set o_data [ create_bd_port -dir O -from 1599 -to 0 o_data ]
  set o_done [ create_bd_port -dir O o_done ]
  set o_nonce [ create_bd_port -dir O -from 7 -to 0 o_nonce ]
  set o_ready [ create_bd_port -dir O o_ready ]
  set rstn [ create_bd_port -dir I -type rst rstn ]
  set rstn_fast [ create_bd_port -dir I -type rst rstn_fast ]
  set rstn_slow [ create_bd_port -dir I -type rst rstn_slow ]

  # Create instance: axi_bram_ctrl_0, and set properties
  set axi_bram_ctrl_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_bram_ctrl:4.1 axi_bram_ctrl_0 ]
  set_property -dict [ list \
   CONFIG.DATA_WIDTH {128} \
   CONFIG.ECC_TYPE {0} \
 ] $axi_bram_ctrl_0

  # Create instance: axi_bram_ctrl_0_bram, and set properties
  set axi_bram_ctrl_0_bram [ create_bd_cell -type ip -vlnv xilinx.com:ip:blk_mem_gen:8.4 axi_bram_ctrl_0_bram ]
  set_property -dict [ list \
   CONFIG.Memory_Type {True_Dual_Port_RAM} \
 ] $axi_bram_ctrl_0_bram

  # Create instance: cryptonight_logic_0, and set properties
  set block_name cryptonight_logic
  set block_cell_name cryptonight_logic_0
  if { [catch {set cryptonight_logic_0 [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $cryptonight_logic_0 eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
    set_property -dict [ list \
   CONFIG.nonce_width {8} \
   CONFIG.scratch_rounds {0x00000010} \
   CONFIG.shuffle_rounds {0x00000010} \
 ] $cryptonight_logic_0

  # Create instance: smartconnect_0, and set properties
  set smartconnect_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 smartconnect_0 ]
  set_property -dict [ list \
   CONFIG.ADVANCED_PROPERTIES { __view__ { functional { S00_Buffer { W_SIZE 256 } } }} \
   CONFIG.NUM_CLKS {3} \
   CONFIG.NUM_SI {3} \
 ] $smartconnect_0

  # Create interface connections
  connect_bd_intf_net -intf_net axi_bram_ctrl_0_BRAM_PORTA [get_bd_intf_pins axi_bram_ctrl_0/BRAM_PORTA] [get_bd_intf_pins axi_bram_ctrl_0_bram/BRAM_PORTA]
  connect_bd_intf_net -intf_net axi_bram_ctrl_0_BRAM_PORTB [get_bd_intf_pins axi_bram_ctrl_0/BRAM_PORTB] [get_bd_intf_pins axi_bram_ctrl_0_bram/BRAM_PORTB]
  connect_bd_intf_net -intf_net cryptonight_logic_0_m00_axi [get_bd_intf_pins cryptonight_logic_0/m00_axi] [get_bd_intf_pins smartconnect_0/S00_AXI]
  connect_bd_intf_net -intf_net cryptonight_logic_0_m01_axi [get_bd_intf_pins cryptonight_logic_0/m01_axi] [get_bd_intf_pins smartconnect_0/S01_AXI]
  connect_bd_intf_net -intf_net cryptonight_logic_0_m02_axi [get_bd_intf_pins cryptonight_logic_0/m02_axi] [get_bd_intf_pins smartconnect_0/S02_AXI]
  connect_bd_intf_net -intf_net smartconnect_0_M00_AXI [get_bd_intf_pins axi_bram_ctrl_0/S_AXI] [get_bd_intf_pins smartconnect_0/M00_AXI]

  # Create port connections
  connect_bd_net -net axi_base_addr_1 [get_bd_ports axi_base_addr] [get_bd_pins cryptonight_logic_0/axi_base_addr]
  connect_bd_net -net clk_1 [get_bd_ports clk] [get_bd_pins axi_bram_ctrl_0/s_axi_aclk] [get_bd_pins cryptonight_logic_0/clk_ap] [get_bd_pins smartconnect_0/aclk]
  connect_bd_net -net clk_fast_1 [get_bd_ports clk_fast] [get_bd_pins cryptonight_logic_0/clk_fast] [get_bd_pins cryptonight_logic_0/m01_axi_aclk] [get_bd_pins smartconnect_0/aclk2]
  connect_bd_net -net clk_slow_1 [get_bd_ports clk_slow] [get_bd_pins cryptonight_logic_0/clk_slow] [get_bd_pins cryptonight_logic_0/m00_axi_aclk] [get_bd_pins cryptonight_logic_0/m02_axi_aclk] [get_bd_pins smartconnect_0/aclk1]
  connect_bd_net -net cryptonight_logic_0_o_data [get_bd_ports o_data] [get_bd_pins cryptonight_logic_0/o_data]
  connect_bd_net -net cryptonight_logic_0_o_done [get_bd_ports o_done] [get_bd_pins cryptonight_logic_0/o_done]
  connect_bd_net -net cryptonight_logic_0_o_nonce [get_bd_ports o_nonce] [get_bd_pins cryptonight_logic_0/o_nonce]
  connect_bd_net -net cryptonight_logic_0_o_ready [get_bd_ports o_ready] [get_bd_pins cryptonight_logic_0/o_ready]
  connect_bd_net -net i_nonce_1 [get_bd_ports i_nonce] [get_bd_pins cryptonight_logic_0/i_nonce]
  connect_bd_net -net i_state_1 [get_bd_ports i_state] [get_bd_pins cryptonight_logic_0/i_state]
  connect_bd_net -net i_valid_1 [get_bd_ports i_valid] [get_bd_pins cryptonight_logic_0/i_valid]
  connect_bd_net -net rstn_1 [get_bd_ports rstn] [get_bd_pins axi_bram_ctrl_0/s_axi_aresetn] [get_bd_pins smartconnect_0/aresetn]
  connect_bd_net -net rstn_fast_1 [get_bd_ports rstn_fast] [get_bd_pins cryptonight_logic_0/rstn_fast]
  connect_bd_net -net rstn_slow_1 [get_bd_ports rstn_slow] [get_bd_pins cryptonight_logic_0/rstn_slow]

  # Create address segments
  assign_bd_address -offset 0x00000000 -range 0x00400000 -target_address_space [get_bd_addr_spaces cryptonight_logic_0/m00_axi] [get_bd_addr_segs axi_bram_ctrl_0/S_AXI/Mem0] -force
  assign_bd_address -offset 0x00000000 -range 0x00400000 -target_address_space [get_bd_addr_spaces cryptonight_logic_0/m01_axi] [get_bd_addr_segs axi_bram_ctrl_0/S_AXI/Mem0] -force
  assign_bd_address -offset 0x00000000 -range 0x00400000 -target_address_space [get_bd_addr_spaces cryptonight_logic_0/m02_axi] [get_bd_addr_segs axi_bram_ctrl_0/S_AXI/Mem0] -force


  # Restore current instance
  current_bd_instance $oldCurInst

  save_bd_design
}
# End of create_root_design()


##################################################################
# MAIN FLOW
##################################################################

create_root_design ""


common::send_gid_msg -ssname BD::TCL -id 2053 -severity "WARNING" "This Tcl script was generated from a block design that has not been validated. It is possible that design <$design_name> may result in errors during validation."


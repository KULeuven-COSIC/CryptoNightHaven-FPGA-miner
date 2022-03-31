create_ip                                     \
  -name         div_gen                       \
  -vendor       xilinx.com                    \
  -library      ip                            \
  -version      5.1                           \
  -module_name  div_gen_0
set_property -dict [
  list                                        \
    CONFIG.dividend_and_quotient_width  {64}  \
    CONFIG.divisor_width                {32}  \
    CONFIG.fractional_width             {32}  \
    CONFIG.latency                      {68}  \
    ] [get_ips div_gen_0]
set_property generate_synth_checkpoint 0 [get_files div_gen_0.xci]

create_ip                                     \
  -name         fifo_generator                \
  -vendor       xilinx.com                    \
  -library      ip                            \
  -version      13.2                          \
  -module_name  cdc_fifo
set_property -dict [
    list                                                                       \
      CONFIG.Fifo_Implementation          {Independent_Clocks_Distributed_RAM} \
      CONFIG.synchronization_stages       {3}                                  \
      CONFIG.Performance_Options          {Standard_FIFO}                      \
      CONFIG.Input_Data_Width             {64}                                 \
      CONFIG.Input_Depth                  {16}                                 \
      CONFIG.Output_Data_Width            {64}                                 \
      CONFIG.Output_Depth                 {16}                                 \
      CONFIG.Reset_Pin                    {false}                              \
      CONFIG.Reset_Type                   {Asynchronous_Reset}                 \
      CONFIG.Full_Flags_Reset_Value       {0}                                  \
      CONFIG.Use_Dout_Reset               {false}                              \
      CONFIG.Use_Extra_Logic              {false}                              \
      CONFIG.Data_Count_Width             {4}                                  \
      CONFIG.Write_Data_Count_Width       {4}                                  \
      CONFIG.Read_Data_Count_Width        {4}                                  \
      CONFIG.Full_Threshold_Assert_Value  {13}                                 \
      CONFIG.Full_Threshold_Negate_Value  {12}                                 \
      CONFIG.Empty_Threshold_Assert_Value {2}                                  \
      CONFIG.Empty_Threshold_Negate_Value {3}                                  \
  ] [get_ips cdc_fifo]
set_property generate_synth_checkpoint 0 [get_files cdc_fifo.xci]

create_ip                                   \
  -name         clk_wiz                     \
  -vendor       xilinx.com                  \
  -library      ip                          \
  -version      6.0                         \
  -module_name  clk_wizard
 set_property -dict [
   list                                                                        \
    CONFIG.CLKOUT1_JITTER                  {114.829}                           \
    CONFIG.CLKOUT1_PHASE_ERROR             {98.575}                            \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ      {200.000}                           \
    CONFIG.CLKOUT2_JITTER                  {97.082}                            \
    CONFIG.CLKOUT2_PHASE_ERROR             {98.575}                            \
    CONFIG.CLKOUT2_REQUESTED_OUT_FREQ      {500.000}                           \
    CONFIG.CLKOUT2_USED                    {true}                              \
    CONFIG.CLK_OUT1_PORT                   {clk_slow}                          \
    CONFIG.CLK_OUT2_PORT                   {clk_fast}                          \
    CONFIG.MMCM_CLKFBOUT_MULT_F            {10.000}                            \
    CONFIG.MMCM_CLKOUT0_DIVIDE_F           {5.000}                             \
    CONFIG.MMCM_CLKOUT1_DIVIDE             {2}                                 \
    CONFIG.NUM_OUT_CLKS                    {2}                                 \
    CONFIG.OPTIMIZE_CLOCKING_STRUCTURE_EN  {true}                              \
    CONFIG.RESET_PORT                      {resetn}                            \
    CONFIG.RESET_TYPE                      {ACTIVE_LOW}                        \
    CONFIG.USE_LOCKED                      {false}                             \
 ] [get_ips clk_wizard]
set_property generate_synth_checkpoint 0 [get_files clk_wizard.xci]

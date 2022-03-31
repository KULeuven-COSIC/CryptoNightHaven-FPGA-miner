//////////////////////////////////////////////////////////////////////////////////
//TASK: Implement a 'parametric' multi-bit implementation of the register
//////////////////////////////////////////////////////////////////////////////////


module Flex_register
        #(parameter SIZE = 4)
        (input wire i_clk, i_rst, input wire[SIZE-1:0] i_v_data, input wire i_v_enable, output reg[SIZE-1:0] o_v_data);
        
        always @(posedge i_clk)
            o_v_data = (i_rst) ? 0: (i_v_enable) ? i_v_data : o_v_data;
//        always @(posedge i_rst)
//            o_v_data = 0;
//STUDENT CODE


endmodule
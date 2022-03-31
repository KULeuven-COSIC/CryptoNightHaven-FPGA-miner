module Keccak_p1600(
input i_clk, // clock
input i_rst, // synchronous reset, active high
input i_start, // start permutation signal
input [1599:0] i_v_state, // input state to the permutation
input [4:0] i_v_numberOfRounds, // vector signal that indicates how many permutations should be executed
output [1599:0] o_v_state, // output state of the permutation
output o_done // permutation done signal
);

    wire sel_input;
    wire[4:0] round_number;
    wire enable;
    wire mode;
    Keccak_p1600_controller Control(i_clk, i_rst, i_start, i_v_numberOfRounds, o_done, sel_input,
                                        round_number, enable, mode);
    Keccak_p1600_datapath Datapath(i_clk, i_rst, enable, sel_input, mode,
                                        round_number, i_v_state, o_v_state);

endmodule
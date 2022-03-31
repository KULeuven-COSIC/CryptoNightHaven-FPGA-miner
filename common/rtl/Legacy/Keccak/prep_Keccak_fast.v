module prep_Keccak_fast(
    input [607:0] i_v_data,
    input i_v_size, // dummy input but this makes for easy switching between fast and slow
    output [1599:0] o_v_data
    );
    // assumes that input size is 76 bytes = 608 bits
    assign o_v_data = {512'b0, 1'b1, 478'b0, 1'b1, i_v_data};
endmodule

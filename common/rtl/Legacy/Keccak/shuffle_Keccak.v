module shuffle_Keccak(
    input [1599:0] i_v_data,
    output [1599:0] o_v_data
    );
    genvar i;
    generate
    for (i=0; i < 1600; i = i + 64) begin
        assign o_v_data[i+63:i+48] = i_v_data[i+15:i   ];
        assign o_v_data[i+47:i+32] = i_v_data[i+31:i+16];
        assign o_v_data[i+31:i+16] = i_v_data[i+47:i+32];
        assign o_v_data[i+15:i   ] = i_v_data[i+63:i+48];
    end
    endgenerate
endmodule

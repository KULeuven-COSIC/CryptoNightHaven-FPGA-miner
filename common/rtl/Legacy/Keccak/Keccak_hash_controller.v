`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/23/2020 02:01:24 PM
// Design Name: 
// Module Name: Keccak_hash_controller
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module Keccak_hash_controller 
  #(parameter L = 160, 
    parameter d = 128,
    parameter b = 400,
    parameter r = 128
    )(
    input i_clk,
    input i_rst,
    input i_start,
    input wire i_f_done,
    input [1:0] i_v_absorb_runs,
    output reg o_f_start,
    output reg o_enable_P,
    output reg o_enable_f_in,
    output reg o_rotate_P,
    output reg o_enable_so,
    output reg o_rst_datapath,
    output o_done
    );
    
    reg[2:0] CurrentState, NextState;
    localparam IdleState = 3'h0;
    localparam StartState = 3'h1;
    localparam AbsorbXORState = 3'h2;
    localparam AbsorbWaitState = 3'h3;
    localparam AbsorbOutputState = 3'h4;
    localparam SqueezeState = 3'h5;
    localparam OutputState = 3'h6;
    localparam AbsorbStartState = 3'h7;
    
    localparam c = b-r; // capacity
    localparam n = (L + r-1)/r; // number of times r fits in L + padding
    localparam m = (d+r-1)/r; // amount of times r fits in d (rounded up)
    
    assign o_done = (CurrentState == OutputState);
    
    always @(posedge i_clk, posedge i_rst)
        if (i_rst) begin
            CurrentState <= IdleState;
            end
        else
            CurrentState <= NextState;
            
    always @(CurrentState, i_rst)
        if (~i_rst) begin
            case(CurrentState)
            IdleState: begin
                o_f_start <= 0;
                o_enable_P <= 0;
                o_enable_f_in <= 0;
                o_rotate_P <= 0;
                o_enable_so <= 0;
                o_rst_datapath <= 1;
//                absorb_runs <= 0;
                end
            StartState: begin
                o_f_start <= 0;
                o_enable_P <= 1;
                o_enable_f_in <= 0;
                o_rotate_P <= 0;
                o_enable_so <= 0;
                o_rst_datapath <= 0;
                end
            AbsorbXORState: begin
                o_f_start <= 0;  //different from synth hash because f_in now as a flex_reg
                o_enable_P <= 0;
                o_enable_f_in <= 1;
                o_rotate_P <= 0;
                o_enable_so <= 0;
//                absorb_runs <= absorb_runs + 1;
                o_rst_datapath <= 0;
                end
            AbsorbStartState: begin
                o_f_start <= 1;
                o_enable_P <= 0;
                o_enable_f_in <= 0;
                o_rotate_P <= 0;
                o_enable_so <= 0;
                o_rst_datapath <= 0;
                end
            AbsorbWaitState: begin
                o_f_start <= 0;
                o_enable_P <= 0;
                o_enable_f_in <= 0;
                o_rotate_P <= 0;
                o_enable_so <= 0;
                o_rst_datapath <= 0;
                end
            AbsorbOutputState: begin
                // In the first implementation I created the datapath myself
                // I had trouble using different indices in P for each iteration
                // so I decided to shift P by r bits instead.
                // This is an artefact but it works
                o_f_start <= 0;
                o_enable_P <= 1;
                o_enable_f_in <= 0;
                o_rotate_P <= 1;
                o_enable_so <= 0;
                o_rst_datapath <= 0;
                end
            SqueezeState: begin
                o_f_start <= 0;
                o_enable_P <= 0;
                o_enable_f_in <= 0;
                o_rotate_P <= 0;
                o_enable_so <= 1;
                o_rst_datapath <= 0;
                end
            OutputState: begin
                o_f_start <= 0;
                o_enable_P <= 0;
                o_enable_f_in <= 0;
                o_rotate_P <= 0;
                o_enable_so <= 0;
//                absorb_runs <= 0;
                o_rst_datapath <= 0;   
                end
            default: begin
                o_f_start <= 0;
                o_enable_P <= 0;
                o_enable_f_in <= 0;
                o_rotate_P <= 0;
                o_enable_so <= 0;
                o_rst_datapath <= 1;
                end
            endcase
        end
        else begin
            o_f_start <= 0;
            o_enable_P <= 0;
            o_enable_f_in <= 0;
            o_rotate_P <= 0;
            o_enable_so <= 0;
            //absorb_runs <= 0;
            o_rst_datapath <= 0;
        end
        
    always @(CurrentState, i_start, i_v_absorb_runs, i_f_done, i_rst) begin
        if (i_rst)
            NextState <= IdleState;
        else begin
            case (CurrentState)
            IdleState: begin
            if (i_start) NextState <= StartState;
            else NextState <= IdleState;
            //else if (NextState == StartState) NextState <= AbsorbXORState;
            //else NextState <= IdleState;
            end
            
            StartState: NextState <= AbsorbXORState; //NextState <= AbsorbStartState;
            
            AbsorbXORState: begin
//                if (NextState == AbsorbStartState)
//                    NextState <= AbsorbWaitState;
//                else
                    NextState <= AbsorbStartState;
            end
            
            AbsorbStartState: NextState <= AbsorbWaitState;
            
            AbsorbWaitState: begin
            if (i_f_done) NextState <= AbsorbOutputState;
            else NextState <= AbsorbWaitState;
            //else if (NextState == AbsorbOutputState) begin
            //    if (absorb_runs == n) NextState <= SqueezeState;
            //    else NextState <= AbsorbXORState;
            //end
            //else NextState <= AbsorbWaitState;
            end
            
            AbsorbOutputState: begin
            if (i_v_absorb_runs == n) NextState <= SqueezeState;
            else NextState <= AbsorbXORState;
            end
            
            SqueezeState: NextState <= OutputState;
            
            OutputState: NextState <= IdleState;
            
            default: NextState <= IdleState;
            
            endcase
        end
    end
    
endmodule

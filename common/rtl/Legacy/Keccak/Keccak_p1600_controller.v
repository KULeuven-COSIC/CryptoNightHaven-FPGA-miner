module Keccak_p1600_controller(input wire i_clk, input wire i_rst, input wire i_start, input wire[4:0] i_v_num_rounds,
        output reg o_done, output reg o_sel_input, output reg[4:0] o_round_number, output reg o_enable, output wire o_mode
    );
    
    reg[1:0] CurrentState, NextState;
    
    parameter IdleState = 2'b00;
    parameter FirstRound = 2'b01;
    parameter RoundingIP = 2'b10;
    parameter OutputState = 2'b11;
    
    assign o_mode = (i_v_num_rounds == 24);
    
    always @(posedge i_clk)
        if (i_rst) begin
            CurrentState <= IdleState;
            o_round_number <= 24 - i_v_num_rounds;
            end

        else begin
            CurrentState <= NextState;
            o_round_number <= (CurrentState == FirstRound || CurrentState == RoundingIP || CurrentState == OutputState) ? o_round_number + 1: 24 - i_v_num_rounds;
            end
    
    always @(CurrentState, i_start, o_round_number)
        if (i_rst)
            NextState <= IdleState;
        else begin
            case (CurrentState)
            IdleState:
                if (i_start) begin
                    if (i_v_num_rounds > 1)
                        NextState <= FirstRound;
                    else
                        NextState <= OutputState;
                    end
                else
                    NextState <= IdleState;
            FirstRound:
                begin
                NextState <= RoundingIP;
                end
            RoundingIP:
                if (o_round_number == 22) // -1 for zero based indexing -1 because after this is triggered one more round will be executed
                    NextState <= OutputState;
                else
                    begin
                    NextState <= RoundingIP;
                    end
            OutputState:
                NextState <= IdleState;
            endcase
        end
        
        always @(CurrentState, i_v_num_rounds) begin
            case(CurrentState)
                IdleState: begin
                    o_enable <= 1;
                    o_done <= 0;
                    o_sel_input <= 0;
                    end
                FirstRound: begin
                    o_enable <= 1;
                    o_done <= 0;
                    o_sel_input <= 1;
                    end
                RoundingIP: begin
                    o_enable <= 1;
                    o_done <= 0;
                    o_sel_input <= 1;
                    end
                OutputState: begin
                    o_enable <= 0;
                    o_done <= 1;
                    o_sel_input <= 0;
                    end
            endcase
        end
endmodule
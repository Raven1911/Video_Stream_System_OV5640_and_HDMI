`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/11/2026 12:00:36 AM
// Design Name: 
// Module Name: edge_detector
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



module edge_detector(
    input clk,
    input reset_n,
    input level_edge,
    
    output p_edge,
    output n_edge,
    output any_edge
    );
    
    //Edge detector mearly outputs
    
    reg state_reg, state_next;
    parameter S0 = 1'b0, S1 = 1'b1;
    
    //sequential state regs
    always @(posedge clk, negedge reset_n) begin
        if(~reset_n)
            state_reg <= S0;
        
        else
            state_reg <= state_next;
    end
    
    always @(*) begin
        case(state_reg)
            S0: begin
                if(level_edge)
                    state_next = S1;
                else
                    state_next = S0;
            end
            
            S1: begin
                if(level_edge)
                    state_next = S1;
                else
                    state_next = S0;
            end
            
            default: state_next = S0;   
        endcase
    end
    
    assign p_edge = (state_reg == S0) & level_edge;
    assign n_edge = (state_reg == S1) & ~level_edge;
    assign any_edge = p_edge | n_edge;
    
    
endmodule

`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/16/2025 01:50:25 PM
// Design Name: 
// Module Name: control_frame_buffer_write_only
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
module control_frame_buffer_write_only#(
    parameter ADDR_WIDTH = 32,
    parameter FIFO_DEPTH_WIDTH = 9,
    parameter THRESHOLD_START = 500, 
    parameter THRESHOLD_STOP  = 499 
)(
    input                               clk_i,
    input                               resetn_i,

    input       [15:0]                  resolution_width_i,
    input       [15:0]                  resolution_depth_i,
    input                               empty_i,
    input       [FIFO_DEPTH_WIDTH-1:0]  data_count_r_i,
    input                               n_edge_vsync_i, 
    output                              wr_o,
    output      [ADDR_WIDTH-1:0]        addr_wr_o,
    output                              page_written_once_o
);


    wire    [ADDR_WIDTH-1:0]    total_pixel;
    // assign  total_pixel = (resolution_width_i * resolution_depth_i) - 1;
    assign  total_pixel = 'd307199; 


    localparam STATE_IDLE  = 1'b0;
    localparam STATE_WRITE = 1'b1; 

    //================================================================
    // Registers
    //================================================================
    reg                       state_reg, state_next;
    reg     [ADDR_WIDTH-1:0]  count_pixel_wr_reg, count_pixel_wr_next;
    reg                       page_written_once_reg, page_written_once_next;

    reg     [ADDR_WIDTH-1:0]  addr_wr_o_reg, addr_wr_o_next;
    reg                       wr_o_reg, wr_o_next;

    //================================================================
    always @(posedge clk_i, negedge resetn_i) begin
        if (~resetn_i) begin
            state_reg             <= STATE_IDLE;
            count_pixel_wr_reg    <= {ADDR_WIDTH{1'b0}};
            page_written_once_reg <= 1'b0;
            addr_wr_o_reg         <= {ADDR_WIDTH{1'b0}};
            wr_o_reg              <= 1'b0;
        end
        else begin
            state_reg             <= state_next;
            count_pixel_wr_reg    <= count_pixel_wr_next;
            page_written_once_reg <= page_written_once_next;
            addr_wr_o_reg         <= addr_wr_o_next;
            wr_o_reg              <= wr_o_next;
        end
    end

    always @(*) begin
        state_next             = state_reg;
        count_pixel_wr_next    = count_pixel_wr_reg;
        page_written_once_next = page_written_once_reg;
        addr_wr_o_next         = addr_wr_o_reg;
        wr_o_next              = 1'b0;
        case (state_reg)
            STATE_IDLE: begin
                if (data_count_r_i >= THRESHOLD_START) begin
                    state_next = STATE_WRITE;
                end
            end
            STATE_WRITE: begin
                if (data_count_r_i <= THRESHOLD_STOP) begin
                    state_next = STATE_IDLE;
                end
                else if (~empty_i) begin
                    wr_o_next      = 1'b1;
                    addr_wr_o_next = count_pixel_wr_reg;
                    if ((count_pixel_wr_reg == total_pixel)) begin
                        count_pixel_wr_next = {ADDR_WIDTH{1'b0}};
                        page_written_once_next = 1'b1; 
                    end else begin
                        count_pixel_wr_next = count_pixel_wr_reg + 1;
                    end
                end
            end
            
            default: state_next = STATE_IDLE;
        endcase
        if (page_written_once_reg == 1'b1) begin
            page_written_once_next = 1'b1;
        end

    end
    assign addr_wr_o = addr_wr_o_reg;
    assign wr_o = wr_o_reg;
    assign page_written_once_o = page_written_once_reg;

endmodule
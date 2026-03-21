`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/16/2025 02:11:29 PM
// Design Name: 
// Module Name: control_frame_buffer_read_only
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
module control_frame_buffer_read_only#(
    parameter ADDR_WIDTH = 32,
    parameter READ_STROBE_PERIOD = 4,
    parameter FIFO_DEPTH_WIDTH = 9,
    parameter THRESHOLD_HIGH = 500,
    parameter THRESHOLD_LOW  = 499
)(
    input                               clk_i,
    input                               resetn_i,

    input       [15:0]                  resolution_width_i,
    input       [15:0]                  resolution_depth_i,
    input                               page_written_once_i,
    input       [FIFO_DEPTH_WIDTH-1:0]  data_count_w_i,
    input                               full_i,
    output                              rd_o,
    output      [ADDR_WIDTH-1:0]        addr_rd_o
);

    wire    [ADDR_WIDTH-1:0]    total_pixel;
    // assign  total_pixel = (resolution_width_i * resolution_depth_i) - 1;
    assign  total_pixel = 'd307199; 

    // localparam STROBE_CNT_WIDTH = (READ_STROBE_PERIOD < 2) ? 1 : $clog2(READ_STROBE_PERIOD);

    //================================================================
    // Registers
    //================================================================
    reg     [ADDR_WIDTH-1:0]  count_pixel_rd_reg, count_pixel_rd_next;
    reg                       read_enabled_reg, read_enabled_next;
    reg     [ADDR_WIDTH-1:0]  addr_rd_o_reg, addr_rd_o_next;
    reg                       rd_o_reg, rd_o_next;
    reg     [STROBE_CNT_WIDTH-1:0] read_strobe_cnt_reg, read_strobe_cnt_next;
    reg                       fifo_pause_reg, fifo_pause_next;
    //================================================================
    always @(posedge clk_i, negedge resetn_i) begin
        if (~resetn_i) begin
            count_pixel_rd_reg  <= {ADDR_WIDTH{1'b0}};
            read_enabled_reg    <= 1'b0;
            addr_rd_o_reg       <= {ADDR_WIDTH{1'b0}};
            rd_o_reg            <= 1'b0;
            read_strobe_cnt_reg <= {STROBE_CNT_WIDTH{1'b0}};
            fifo_pause_reg      <= 1'b0; 
        end
        else begin
            count_pixel_rd_reg  <= count_pixel_rd_next;
            read_enabled_reg    <= read_enabled_next;
            addr_rd_o_reg       <= addr_rd_o_next;
            rd_o_reg            <= rd_o_next;
            read_strobe_cnt_reg <= read_strobe_cnt_next;
            fifo_pause_reg      <= fifo_pause_next;
        end
    end
    //================================================================
    always @(*) begin
        fifo_pause_next = fifo_pause_reg;
        if (data_count_w_i >= THRESHOLD_HIGH) begin
            fifo_pause_next = 1'b1;
        end 
        else if (data_count_w_i <= THRESHOLD_LOW) begin
            fifo_pause_next = 1'b0;
        end
    end

    wire can_read_base;
    assign can_read_base = (read_enabled_reg == 1'b1) && (fifo_pause_next == 1'b0) && (full_i == 1'b0);
    
    wire read_strobe_allow;
    assign read_strobe_allow = (read_strobe_cnt_reg == 0);

    always @(*) begin
        count_pixel_rd_next  = count_pixel_rd_reg;
        read_strobe_cnt_next = read_strobe_cnt_reg;
        addr_rd_o_next       = addr_rd_o_reg;
        rd_o_next            = 1'b0;
        read_enabled_next = read_enabled_reg | page_written_once_i;
        if (can_read_base) begin
            // if (READ_STROBE_PERIOD > 1) begin
            //     if (read_strobe_cnt_reg == READ_STROBE_PERIOD - 1)
            //         read_strobe_cnt_next = 0;
            //     else
            //         read_strobe_cnt_next = read_strobe_cnt_reg + 1;
            // end
            // if (read_strobe_allow) begin
            //     rd_o_next = 1'b1;
            //     addr_rd_o_next = count_pixel_rd_reg;
            //     if (count_pixel_rd_reg == total_pixel)
            //         count_pixel_rd_next = {ADDR_WIDTH{1'b0}};
            //     else
            //         count_pixel_rd_next = count_pixel_rd_reg + 1;
            // end
            rd_o_next = 1'b1;
            addr_rd_o_next = count_pixel_rd_reg;

            if (count_pixel_rd_reg == total_pixel)
                count_pixel_rd_next = {ADDR_WIDTH{1'b0}};
            else
                count_pixel_rd_next = count_pixel_rd_reg + 1;
        end
    end

    assign addr_rd_o = addr_rd_o_reg;
    assign rd_o = rd_o_reg;

endmodule

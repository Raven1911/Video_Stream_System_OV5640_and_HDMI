`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/11/2025 11:51:09 AM
// Design Name: 
// Module Name: bram_memory_controller
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


module bram_memory_controller #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 16,
    parameter BURST_LEN  = 32 
)(
    input wire                      clk_i,      // 150MHz
    input wire                      resetn_i,

    input wire [15:0]               resolution_width_i,
    input wire [15:0]               resolution_depth_i,

    // Camera FIFO (Read side)
    input wire [9:0]                fifo_cam_count,
    input wire [DATA_WIDTH-1:0]     fifo_cam_dout,  
    input wire                      fifo_cam_empty,
    output reg                      fifo_cam_rd_en, 

    // HDMI FIFO (Write side)
    input wire [9:0]                fifo_hdmi_count, 
    input wire                      fifo_hdmi_full,
    output reg [DATA_WIDTH-1:0]     fifo_hdmi_din,   
    output reg                      fifo_hdmi_wr_en, 

    // BRAM Interface
    output reg [ADDR_WIDTH-1:0]     bram_addr_wr,
    output reg [DATA_WIDTH-1:0]     bram_data_wr,
    output reg                      bram_we,
    
    output reg [ADDR_WIDTH-1:0]     bram_addr_rd,
    input wire [DATA_WIDTH-1:0]     bram_data_rd,
    output reg                      bram_re 
);

    wire [ADDR_WIDTH-1:0] max_addr;
    assign max_addr = (resolution_width_i * resolution_depth_i) - 1;

    reg [ADDR_WIDTH-1:0] mem_wr_ptr;
    reg [ADDR_WIDTH-1:0] mem_rd_ptr;

    localparam IDLE         = 0;
    localparam BURST_WRITE  = 1; 
    localparam BURST_READ   = 2; 

    reg [2:0] state;
    reg [9:0] req_cnt; // Đếm số lệnh đã gửi đi
    reg [9:0] ack_cnt; // Đếm số dữ liệu đã xử lý xong

    // Hàm tăng địa chỉ (vòng tròn)
    function [ADDR_WIDTH-1:0] next_addr;
        input [ADDR_WIDTH-1:0] current_addr;
        input [ADDR_WIDTH-1:0] max_val;
        begin
            if (current_addr >= max_val)
                next_addr = 0;
            else
                next_addr = current_addr + 1;
        end
    endfunction

    always @(posedge clk_i or negedge resetn_i) begin
        if (!resetn_i) begin
            state <= IDLE;
            mem_wr_ptr <= 0;
            mem_rd_ptr <= 0;
            fifo_cam_rd_en <= 0;
            fifo_hdmi_wr_en <= 0;
            bram_we <= 0;
            bram_re <= 0;
            req_cnt <= 0;
            ack_cnt <= 0;
            bram_addr_wr <= 0;
            bram_addr_rd <= 0;
            bram_data_wr <= 0;
            fifo_hdmi_din <= 0;
        end else begin
            // Reset xung điều khiển (mặc định mức 0)
            fifo_cam_rd_en <= 0;
            bram_we <= 0;
            fifo_hdmi_wr_en <= 0;
            
            // Logic BRAM Read Enable (tuỳ chọn, một số BRAM cần)
            bram_re <= 0; 

            case (state)
                IDLE: begin
                    req_cnt <= 0;
                    ack_cnt <= 0;

                    // Ưu tiên 1: Đọc ra HDMI nếu FIFO vơi (tránh đen màn hình)
                    if (fifo_hdmi_count < (512 - BURST_LEN) && !fifo_hdmi_full) begin
                         state <= BURST_READ;
                    end
                    // Ưu tiên 2: Ghi từ Camera nếu FIFO đầy
                    else if (fifo_cam_count >= BURST_LEN) begin
                        state <= BURST_WRITE;
                    end
                end

                // --------------------------------------------------------
                // BURST WRITE: Đọc FIFO (Standard Mode) -> Ghi BRAM
                // --------------------------------------------------------
                BURST_WRITE: begin
                    // 1. Gửi lệnh ĐỌC (Request)
                    if (req_cnt < BURST_LEN) begin
                        fifo_cam_rd_en <= 1; 
                        req_cnt <= req_cnt + 1;
                    end

                    // 2. Nhận dữ liệu & GHI (Commit)
                    // Với Standard FIFO: Nếu req_cnt > 0 nghĩa là ở cycle trước đã có rd_en=1
                    // -> Dữ liệu input đang hợp lệ NGAY LÚC NÀY.
                    if (req_cnt > 0) begin
                        bram_we <= 1;
                        bram_data_wr <= fifo_cam_dout; // Lấy dữ liệu ngay lập tức
                        bram_addr_wr <= mem_wr_ptr;    
                        
                        mem_wr_ptr <= next_addr(mem_wr_ptr, max_addr);
                        ack_cnt <= ack_cnt + 1;
                    end

                    // 3. Kết thúc
                    if (ack_cnt == BURST_LEN) begin
                        state <= IDLE;
                        bram_we <= 0; // Quan trọng: Ngắt ghi ngay
                    end
                end

                // --------------------------------------------------------
                // BURST READ: Đọc BRAM (Latency 1) -> Ghi FIFO HDMI
                // --------------------------------------------------------
                BURST_READ: begin
                    // 1. Gửi địa chỉ ĐỌC (Request)
                    if (req_cnt < BURST_LEN) begin
                        bram_addr_rd <= mem_rd_ptr;
                        mem_rd_ptr <= next_addr(mem_rd_ptr, max_addr);
                        bram_re <= 1; // Kích hoạt đọc BRAM
                        req_cnt <= req_cnt + 1;
                    end

                    // 2. Nhận dữ liệu & GHI vào FIFO (Commit)
                    // BRAM Latency = 1 (T gửi addr -> T+1 có data)
                    // Nếu req_cnt > 0 -> Data từ BRAM đang hợp lệ ở đầu vào
                    if (req_cnt > 0) begin
                        fifo_hdmi_din <= bram_data_rd;
                        fifo_hdmi_wr_en <= 1;
                        ack_cnt <= ack_cnt + 1;
                    end

                    // 3. Kết thúc
                    if (ack_cnt == BURST_LEN) begin
                        state <= IDLE;
                        fifo_hdmi_wr_en <= 0;
                    end
                end

            endcase
        end
    end

endmodule

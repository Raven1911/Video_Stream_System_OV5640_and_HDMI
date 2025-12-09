`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/16/2025 02:14:02 PM
// Design Name: 
// Module Name: tb_control_frame_buffer_read_only
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


module tb_control_frame_buffer_read_only;

    //================================================================
    // Parameters
    //================================================================
    
    // Đặt ADDR_WIDTH giống như trong module DUT
    parameter ADDR_WIDTH_TB = 32;
    
    // Đặt độ phân giải nhỏ để mô phỏng nhanh
    // (10 pixel rộng x 4 pixel cao = 40 pixels tổng)
    parameter RESOLUTION_W_TB = 16'd10;
    parameter RESOLUTION_D_TB = 16'd4;
    
    // Chu kỳ clock (10ns = 100MHz)
    parameter CLK_PERIOD = 10;

    //================================================================
    // Signals
    //================================================================
    
    // Inputs to DUT
    reg                               clk_tb;
    reg                               resetn_tb;
    reg     [15:0]                    resolution_width_tb;
    reg     [15:0]                    resolution_depth_tb;
    reg                               page_written_once_tb;
    reg                               full_tb;

    // Outputs from DUT
    wire                              rd_tb;
    wire    [ADDR_WIDTH_TB-1:0]       addr_rd_tb;

    //================================================================
    // Instantiate DUT
    //================================================================
    
    control_frame_buffer_read_only #(
        .ADDR_WIDTH(ADDR_WIDTH_TB)
    ) DUT_READ (
        .clk_i(clk_tb),
        .resetn_i(resetn_tb),

        .resolution_width_i(resolution_width_tb),
        .resolution_depth_i(resolution_depth_tb),

        .page_written_once_i(page_written_once_tb),
        .full_i(full_tb),

        .rd_o(rd_tb),
        .addr_rd_o(addr_rd_tb)
    );

    //================================================================
    // Clock Generator
    //================================================================
    
    // Tạo xung clock 100MHz
    always begin
        clk_tb = 1'b0;
        #(CLK_PERIOD / 2);
        clk_tb = 1'b1;
        #(CLK_PERIOD / 2);
    end

    //================================================================
    // Test Sequence (Main)
    //================================================================
    
    initial begin
        $display("-------------------------------------------------");
        $display("--- Bắt đầu Testbench (Read Only) ---");
        $display("-------------------------------------------------");
        
        // --- 1. Khởi tạo và Reset ---
        $display("@%0t: Khởi tạo giá trị và áp dụng Reset...", $time);
        resolution_width_tb  = RESOLUTION_W_TB;
        resolution_depth_tb  = RESOLUTION_D_TB;
        page_written_once_tb = 1'b0; // Module Ghi chưa ghi xong
        full_tb              = 1'b0; // FIFO đầu ra không đầy
        resetn_tb            = 1'b0; // Áp dụng reset (active-low)
        
        #(CLK_PERIOD * 3); // Giữ reset trong 3 chu kỳ
        
        $display("@%0t: Nhả Reset. Chờ tín hiệu 'page_written'...", $time);
        resetn_tb = 1'b1; // Nhả reset
        
        #(CLK_PERIOD * 5); // Chờ 5 chu kỳ
        
        // --- 2. Bắt đầu Đọc (Đã ghi xong 1 trang) ---
        $display("@%0t: Module Ghi báo 'page_written_once' = 1. Bắt đầu đọc...", $time);
        page_written_once_tb = 1'b1; // Báo đã ghi xong 1 trang
        
        // Chờ 20 chu kỳ
        #(CLK_PERIOD * 20);
        
        // --- 3. Dừng Đọc (FIFO đầy) ---
        $display("@%0t: FIFO đầu ra ĐẦY. Tạm dừng đọc.", $time);
        full_tb = 1'b1; // Báo FIFO đầy
        
        #(CLK_PERIOD * 10); // Chờ 10 chu kỳ, bộ đếm nên dừng
        
        // --- 4. Đọc tiếp (FIFO hết đầy) ---
        $display("@%0t: FIFO hết đầy. Đọc tiếp.", $time);
        full_tb = 1'b0; // Báo FIFO hết đầy
        
        // Chờ cho đến khi đọc hết trang (tổng 40 pixel) và lặp lại
        #(CLK_PERIOD * 30); 
        
        // --- 5. Kết thúc ---
        $display("@%0t: Hoàn thành mô phỏng.", $time);
        $display("-------------------------------------------------");
        $finish;
    end

    //================================================================
    // Monitor (Theo dõi tín hiệu)
    //================================================================
    
    // In ra các tín hiệu mỗi khi clock thay đổi
    initial begin
        $monitor("@%0t: clk=%b, rstn=%b | page_written=%b, full=%b | rd=%b, addr_rd=%d",
                 $time, clk_tb, resetn_tb, page_written_once_tb, full_tb, rd_tb, addr_rd_tb);
    end

endmodule

`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/16/2025 01:52:11 PM
// Design Name: 
// Module Name: tb_control_frame_buffer_write
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



module tb_control_frame_buffer_write;

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
    reg                               empty_tb;

    // Outputs from DUT
    wire                              wr_tb;
    wire    [ADDR_WIDTH_TB-1:0]       addr_wr_tb;
    wire                              page_written_once_tb;

    //================================================================
    // Instantiate DUT
    //================================================================
    
    control_frame_buffer_write_only #(
        .ADDR_WIDTH(ADDR_WIDTH_TB)
    ) DUT (
        .clk_i(clk_tb),
        .resetn_i(resetn_tb),

        .resolution_width_i(resolution_width_tb),
        .resolution_depth_i(resolution_depth_tb),

        .empty_i(empty_tb), 

        .wr_o(wr_tb),
        .addr_wr_o(addr_wr_tb),
        .page_written_once_o(page_written_once_tb)
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
        $display("--- Bắt đầu Testbench ---");
        $display("-------------------------------------------------");
        
        // --- 1. Khởi tạo và Reset ---
        $display("@%0t: Khởi tạo giá trị và áp dụng Reset...", $time);
        resolution_width_tb  = RESOLUTION_W_TB;
        resolution_depth_tb  = RESOLUTION_D_TB;
        empty_tb             = 1'b1; // FIFO rỗng
        resetn_tb            = 1'b0; // Áp dụng reset (active-low)
        
        #(CLK_PERIOD * 3); // Giữ reset trong 3 chu kỳ
        
        $display("@%0t: Nhả Reset. FIFO vẫn rỗng.", $time);
        resetn_tb = 1'b1; // Nhả reset
        
        #(CLK_PERIOD * 5); // Chờ 5 chu kỳ
        
        // --- 2. Bắt đầu Ghi (FIFO có data) ---
        $display("@%0t: FIFO có dữ liệu. Bắt đầu ghi...", $time);
        empty_tb = 1'b0; // Báo FIFO có data
        
        // Chờ cho đến khi ghi xong 1 trang
        // Tổng số pixel = 10 * 4 = 40. Sẽ mất 40 chu kỳ
        // Ta chờ 45 chu kỳ để xem nó quay vòng
        #(CLK_PERIOD * 45);
        
        // --- 3. Dừng Ghi (FIFO rỗng) ---
        $display("@%0t: FIFO rỗng. Dừng ghi.", $time);
        empty_tb = 1'b1; // Báo FIFO rỗng
        
        #(CLK_PERIOD * 10); // Chờ 10 chu kỳ, bộ đếm nên dừng
        
        // --- 4. Ghi tiếp ---
        $display("@%0t: FIFO lại có dữ liệu. Ghi tiếp.", $time);
        empty_tb = 1'b0; // Báo FIFO có data
        
        #(CLK_PERIOD * 10); // Ghi thêm 10 pixel
        
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
        $monitor("@%0t: clk=%b, rstn=%b | empty=%b | wr=%b, addr_wr=%d, page_written=%b",
                 $time, clk_tb, resetn_tb, empty_tb, wr_tb, addr_wr_tb, page_written_once_tb);
    end

endmodule
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/28/2025 10:06:31 PM
// Design Name: 
// Module Name: tb_control_frame_buffer
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

module tb_control_frame_buffer;

    //================================================================
    // Tham số Testbench
    //================================================================
    localparam  ADDR_WIDTH = 32;
    localparam  DATA_WIDTH = 16;
    localparam  CLK_PERIOD = 10; // 10ns = 100MHz

    // Độ phân giải thử nghiệm (nhỏ để dễ xem)
    localparam  RES_W = 8;
    localparam  RES_H = 4;
    localparam  TOTAL_PIXELS = RES_W * RES_H; // 32 pixels

    //================================================================
    // Tín hiệu
    //================================================================
    reg                       clk_i;
    reg                       resetn_i;
    reg         [15:0]        resolution_width_i;
    reg         [15:0]        resolution_depth_i;
    reg                       empty_i;
    reg                       full_i;

    wire                      wr_o;
    wire                      rd_o;
    wire        [ADDR_WIDTH-1:0]  addr_wr_o;
    wire        [ADDR_WIDTH-1:0]  addr_rd_o;

    //================================================================
    // Khởi tạo DUT (Design Under Test)
    //================================================================
    control_frame_buffer #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .clk_i(clk_i),
        .resetn_i(resetn_i),
        .resolution_width_i(resolution_width_i),
        .resolution_depth_i(resolution_depth_i),
        .empty_i(empty_i),
        .full_i(full_i),
        .wr_o(wr_o),
        .rd_o(rd_o),
        .addr_wr_o(addr_wr_o),
        .addr_rd_o(addr_rd_o)
    );

    //================================================================
    // Tạo Clock
    //================================================================
    always #(CLK_PERIOD / 2) begin
        clk_i = ~clk_i;
    end

    //================================================================
    // Quy trình Test
    //================================================================
    initial begin
        // --- 1. Khởi tạo ---
        $display("--- BAT DAU MO PHONG ---");
        clk_i = 0;
        resetn_i = 0;
        resolution_width_i = RES_W;
        resolution_depth_i = RES_H;
        empty_i = 1; // Đầu vào rỗng
        full_i = 1;  // Đầu ra đầy

        // --- 2. Áp dụng Reset ---
        #(CLK_PERIOD * 2);
        resetn_i = 1;
        $display("Time: %0t | RESET da duoc tha.", $time);

        // --- 3. Test Case 1: Luồng chạy bình thường ---
        $display("Time: %0t | Test 1: Luong chay binh thuong.", $time);
        empty_i = 0; // Đầu vào CÓ data
        full_i = 0;  // Đầu ra KHÔNG đầy

        // In tiêu đề
        $display("==========================================================");
        $display("Time (ns) | wr_en | addr_wr | rd_en | addr_rd | Ghi chu");
        $display("==========================================================");
        
        // Sử dụng $monitor để theo dõi tín hiệu mỗi khi chúng thay đổi
        $monitor("%8d    |   %b   | %7d |   %b   | %7d |", 
                 $time, wr_o, addr_wr_o, rd_o, addr_rd_o);

        // Chạy mô phỏng cho hơn 1 khung hình (32 pixels + 10)
        #(CLK_PERIOD * (TOTAL_PIXELS + 10));

        // --- 4. Test Case 2: Tạm dừng Ghi (Input Empty) ---
        $display("\nTime: %0t | Test 2: Tam dung Ghi (Input Empty).", $time);
        empty_i = 1; // Đầu vào RỖNG
        #(CLK_PERIOD * 5);
        $display("Time: %0t | Tiep tuc Ghi.", $time);
        empty_i = 0; // Đầu vào CÓ data
        #(CLK_PERIOD * 5);


        // --- 5. Test Case 3: Tạm dừng Đọc (Output Full) ---
        $display("\nTime: %0t | Test 3: Tam dung Doc (Output Full).", $time);
        full_i = 1; // Đầu ra ĐẦY
        #(CLK_PERIOD * 5);
        $display("Time: %0t | Tiep tuc Doc.", $time);
        full_i = 0; // Đầu ra KHÔNG đầy
        #(CLK_PERIOD * 5);


        // --- 6. Kết thúc ---
        $display("\nTime: %0t | --- KET THUC MO PHONG ---", $time);
        $stop;
    end

endmodule


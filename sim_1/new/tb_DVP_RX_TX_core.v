`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/30/2025 11:17:45 AM
// Design Name: 
// Module Name: tb_DVP_RX_TX_core
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

module tb_DVP_RX_TX_core;

    //================================================================
    // Parameters
    //================================================================
    
    // --- DUT Parameters ---
    parameter DATA_WIDTH        = 8;
    parameter ADDR_WIDTH_FIFO   = 11;
    parameter DATA_WIDTH_FIFO   = 16;
    parameter BRAM_ADDR_WIDTH   = 32;
    parameter BRAM_DATA_WIDTH   = 16;
    parameter BRAM_NUMBER_BLOCK = 75;
    parameter BRAM_DEPTH_SIZE   = 4096;
    parameter BRAM_MODE         = 2;
    
    // --- Testbench Parameters ---
    parameter CLK_PERIOD      = 10; // System clock @ 100MHz
    parameter CAM_PCLK_PERIOD = 40; // Camera clock @ 25MHz
    
    parameter TEST_WIDTH      = 640;
    parameter TEST_HEIGHT     = 480;

    //================================================================
    // Testbench Signals (DUT Inputs)
    //================================================================
    reg                         clk_i;
    reg                         resetn_i;
    reg                         cam_pclk_i;
    reg [DATA_WIDTH-1:0]        cam_half_pixel_i;
    reg                         cam_href;
    reg                         cam_vsync;
    reg [15:0]                  resolution_width_i;
    reg [15:0]                  resolution_depth_i;

    // (DUT có vẻ không có output nào ở top-level, 
    // nếu có, hãy khai báo chúng là 'wire' ở đây)


    //================================================================
    // Instantiate the Unit Under Test (DUT)
    //================================================================
    DVP_RX_TX_core #(
        .DATA_WIDTH         (DATA_WIDTH),
        .ADDR_WIDTH_FIFO    (ADDR_WIDTH_FIFO),
        .DATA_WIDTH_FIFO    (DATA_WIDTH_FIFO),
        .BRAM_ADDR_WIDTH    (BRAM_ADDR_WIDTH),
        .BRAM_DATA_WIDTH    (BRAM_DATA_WIDTH),
        .BRAM_NUMBER_BLOCK  (BRAM_NUMBER_BLOCK),
        .BRAM_DEPTH_SIZE    (BRAM_DEPTH_SIZE),
        .BRAM_MODE          (BRAM_MODE)
    ) uut (
        // System Clock Domain
        .clk_i              (clk_i),
        .resetn_i           (resetn_i),

        // Camera Interface
        .cam_pclk_i         (cam_pclk_i),
        .cam_half_pixel_i   (cam_half_pixel_i),
        .cam_href           (cam_href),
        .cam_vsync          (cam_vsync),

        // Config frame
        .resolution_width_i (resolution_width_i),
        .resolution_depth_i (resolution_depth_i)
        
        // (Kết nối các output của DUT nếu có)
    );

    //================================================================
    // Clock Generators
    //================================================================
    
    // System Clock (100MHz)
    always begin
        clk_i = 1'b0;
        #(CLK_PERIOD / 2);
        clk_i = 1'b1;
        #(CLK_PERIOD / 2);
    end

    // Camera Pixel Clock (25MHz)
    always begin
        cam_pclk_i = 1'b0;
        #(CAM_PCLK_PERIOD / 2);
        cam_pclk_i = 1'b1;
        #(CAM_PCLK_PERIOD / 2);
    end

    //================================================================
    // Main Test Sequence
    //================================================================
    initial begin
        // Dump waves (Tùy chọn, cho mô phỏng)
        $dumpfile("tb_DVP_RX_TX_core.vcd");
        $dumpvars(0, tb_DVP_RX_TX_core);

        // --- 1. Initialize Inputs ---
        resetn_i           <= 1'b0; // Giữ ở trạng thái reset
        cam_half_pixel_i   <= 8'h00;
        cam_href           <= 1'b0;
        cam_vsync          <= 1'b1; // Thường ở mức cao khi không hoạt động
        resolution_width_i <= TEST_WIDTH;  // 640
        resolution_depth_i <= TEST_HEIGHT; // 480

        // --- 2. Apply Reset ---
        #(CLK_PERIOD * 10); // Chờ 10 chu kỳ clk_i
        resetn_i <= 1'b1;   // Nhả reset
        #(CLK_PERIOD * 10); // Chờ hệ thống ổn định

        // --- 3. Send one frame ---
        $display("[%0t] TB: Bắt đầu gửi khung hình %dx%d...", $time, TEST_WIDTH, TEST_HEIGHT);
        send_frame(TEST_WIDTH, TEST_HEIGHT);
        $display("[%0t] TB: Gửi khung hình hoàn tất.", $time);

        // --- 4. Finish Simulation ---
        #(CLK_PERIOD * 20);
        $finish;
    end

    //================================================================
    // Task: send_frame
    // Mô phỏng việc gửi một khung hình video từ camera.
    //================================================================
    task send_frame;
        input integer WIDTH;
        input integer HEIGHT;
        
        // Biến cục bộ
        integer i, j; // i = hàng (row), j = byte trong hàng
        reg [DATA_WIDTH-1:0] pixel_byte;

        begin
            pixel_byte = 8'h00;

            // --- 1. VSYNC Start (Vertical Blanking) ---
            // Bắt đầu VBLANK
            cam_vsync <= 1'b1;
            cam_href  <= 1'b0;
            repeat(10) @(posedge cam_pclk_i);
            
            // VSYNC falling edge (Bắt đầu 1 khung hình mới)
            cam_vsync <= 1'b0;
            $display("[%0t] TB: VSYNC bắt đầu (falling edge).", $time);
            repeat(20) @(posedge cam_pclk_i); // V-Blanking time

            // --- 2. Loop through all rows (HEIGHT) ---
            for (i = 0; i < HEIGHT; i = i + 1) begin
                
                // --- 2a. Horizontal Front Porch (HBLANK) ---
                cam_href <= 1'b0;
                repeat(20) @(posedge cam_pclk_i); // Giả lập H-Front-Porch

                // --- 2b. Active Line (HREF = 1) ---
                cam_href <= 1'b1;
                
                // Gửi (WIDTH * 2) byte cho mỗi hàng (vì 1 pixel = 2 byte)
                for (j = 0; j < (WIDTH * 2); j = j + 1) begin
                    @(posedge cam_pclk_i);
                    // Tạo dữ liệu pixel giả lập (ví dụ: một mẫu ramp)
                    pixel_byte = (i + j) % 256; 
                    cam_half_pixel_i <= pixel_byte;
                end
                
                // --- 2c. Horizontal Back Porch (HBLANK) ---
                cam_href <= 1'b0;
                repeat(20) @(posedge cam_pclk_i); // Giả lập H-Back-Porch
                
            end // Kết thúc vòng lặp các hàng

            // --- 3. VSYNC End (Vertical Blanking) ---
            $display("[%0t] TB: VSYNC kết thúc (rising edge).", $time);
            cam_vsync <= 1'b1; // Quay lại VBLANK
            repeat(50) @(posedge cam_pclk_i);

        end
    endtask

endmodule


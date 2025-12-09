`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/12/2025 10:35:31 PM
// Design Name: 
// Module Name: tb_DVP_RX_TX_core2
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


module tb_DVP_RX_TX_core2;

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
    parameter CLK_PERIOD      = 10; // 100MHz system clock
    parameter CLK50_PERIOD    = 20; // 50MHz clock (for HDMI IP)
    parameter CLK25_PERIOD    = 40; // 25MHz clock (for HDMI IP)
    parameter CAM_PCLK_PERIOD = 40; // Camera clock @ 25MHz (from user's code)

    parameter TEST_WIDTH      = 640;
    parameter TEST_HEIGHT     = 480;

    //================================================================
    // Signals
    //================================================================

    // System Clocks and Reset
    reg tb_clk_i;
    reg tb_clk25MHz_i;
    reg tb_clk50MHz_i;
    reg tb_resetn_i;

    // Camera Interface
    reg tb_cam_pclk_i;
    reg [DATA_WIDTH-1:0] tb_cam_half_pixel_i;
    reg tb_cam_href;
    reg tb_cam_vsync;

    // Frame Config
    reg [15:0] tb_resolution_width_i;
    reg [15:0] tb_resolution_depth_i;

    // DUT Outputs
    wire tb_hsync;
    wire tb_vsync;
    wire tb_dataEnable;
    wire tb_vgaClock;
    wire [23:0] tb_RGBchannel;

    //================================================================
    // Instantiate DUT
    //================================================================

    DVP_RX_TX_core #(
        .DATA_WIDTH        (DATA_WIDTH),
        .ADDR_WIDTH_FIFO   (ADDR_WIDTH_FIFO),
        .DATA_WIDTH_FIFO   (DATA_WIDTH_FIFO),
        .BRAM_ADDR_WIDTH   (BRAM_ADDR_WIDTH),
        .BRAM_DATA_WIDTH   (BRAM_DATA_WIDTH),
        .BRAM_NUMBER_BLOCK (BRAM_NUMBER_BLOCK),
        .BRAM_DEPTH_SIZE   (BRAM_DEPTH_SIZE),
        .BRAM_MODE         (BRAM_MODE)
    )
    uut (
        // System Clock Domain
        .clk_i               (tb_clk_i),
        .clk25MHz_i          (tb_clk25MHz_i),
        .clk50MHz_i          (tb_clk50MHz_i),
        .resetn_i            (tb_resetn_i),

        // Camera Interface
        .cam_pclk_i          (tb_cam_pclk_i),
        .cam_half_pixel_i    (tb_cam_half_pixel_i),
        .cam_href            (tb_cam_href),
        .cam_vsync           (tb_cam_vsync),

        // DUT Outputs
        .hsync               (tb_hsync),
        .vsync               (tb_vsync),
        .dataEnable          (tb_dataEnable),
        .vgaClock            (tb_vgaClock),
        .RGBchannel          (tb_RGBchannel),

        // Config Frame
        .resolution_width_i  (tb_resolution_width_i),
        .resolution_depth_i  (tb_resolution_depth_i)
    );

    //================================================================
    // Clock Generation
    //================================================================

    // System Clock (100MHz)
    always #((CLK_PERIOD / 2)) tb_clk_i = ~tb_clk_i;

    // 50MHz Clock (for HDMI)
    always #((CLK50_PERIOD / 2)) tb_clk50MHz_i = ~tb_clk50MHz_i;

    // 25MHz Clock (for HDMI)
    always #((CLK25_PERIOD / 2)) tb_clk25MHz_i = ~tb_clk25MHz_i;

    // Camera Pixel Clock (25MHz - based on user's code)
    always #((CAM_PCLK_PERIOD / 2)) tb_cam_pclk_i = ~tb_cam_pclk_i;

    //================================================================
    // Main Test Sequence (Based on user's code)
    //================================================================
    
    initial begin
        // --- 1. Initialize Inputs ---
        tb_clk_i              <= 1'b1;
        tb_clk25MHz_i         <= 1'b1;
        tb_clk50MHz_i         <= 1'b1;
        tb_cam_pclk_i         <= 1'b0;
        
        tb_resetn_i           <= 1'b0; // Giữ ở trạng thái reset
        tb_cam_half_pixel_i   <= 8'h00;
        tb_cam_href           <= 1'b0;
        tb_cam_vsync          <= 1'b1; // Thường ở mức cao khi không hoạt động
        tb_resolution_width_i <= TEST_WIDTH;  // 640
        tb_resolution_depth_i <= TEST_HEIGHT; // 480

        // --- 2. Apply Reset ---
        #(CLK_PERIOD * 10); // Chờ 10 chu kỳ clk_i
        tb_resetn_i <= 1'b1;   // Nhả reset
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
    // Task: send_frame (From user's code, signals renamed)
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
            tb_cam_vsync <= 1'b1;
            tb_cam_href  <= 1'b0;
            repeat(10) @(posedge tb_cam_pclk_i);
            
            // VSYNC falling edge (Bắt đầu 1 khung hình mới)
            tb_cam_vsync <= 1'b0;
            $display("[%0t] TB: VSYNC bắt đầu (falling edge).", $time);
            repeat(20) @(posedge tb_cam_pclk_i); // V-Blanking time

            // --- 2. Loop through all rows (HEIGHT) ---
            for (i = 0; i < HEIGHT; i = i + 1) begin
                
                // --- 2a. Horizontal Front Porch (HBLANK) ---
                tb_cam_href <= 1'b0;
                repeat(20) @(posedge tb_cam_pclk_i); // Giả lập H-Front-Porch

                // --- 2b. Active Line (HREF = 1) ---
                tb_cam_href <= 1'b1;
                
                // Gửi (WIDTH * 2) byte cho mỗi hàng (vì 1 pixel = 2 byte)
                for (j = 0; j < (WIDTH * 2); j = j + 1) begin
                    @(posedge tb_cam_pclk_i);
                    // Tạo dữ liệu pixel giả lập (ví dụ: một mẫu ramp)
                    pixel_byte = (i + j) % 256; 
                    tb_cam_half_pixel_i <= pixel_byte;
                end
                
                // --- 2c. Horizontal Back Porch (HBLANK) ---
                tb_cam_href <= 1'b0;
                repeat(20) @(posedge tb_cam_pclk_i); // Giả lập H-Back-Porch
                
            end // Kết thúc vòng lặp các hàng

            // --- 3. VSYNC End (Vertical Blanking) ---
            $display("[%0t] TB: VSYNC kết thúc (rising edge).", $time);
            tb_cam_vsync <= 1'b1; // Quay lại VBLANK
            repeat(50) @(posedge tb_cam_pclk_i);

        end
    endtask

    //================================================================
    // Simulation Control
    //================================G================================
    
    // Optional: Dump waves
    initial begin
        $dumpfile("tb_DVP_RX_TX_core2.vcd");
        // Đổi module name ở đây nếu bạn đổi tên file
        $dumpvars(0, tb_DVP_RX_TX_core2); 
    end

endmodule
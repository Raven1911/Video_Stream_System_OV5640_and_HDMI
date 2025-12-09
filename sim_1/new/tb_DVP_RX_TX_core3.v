`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/03/2025 04:32:48 PM
// Design Name: 
// Module Name: tb_DVP_RX_TX_core3
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


`timescale 1ns / 1ps

module tb_DVP_RX_TX_core3;

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
    parameter CAM_PCLK_PERIOD = 40; // Camera clock @ 25MHz

    // Để mô phỏng nhanh hơn, ta có thể giảm kích thước ảnh. 
    // Tuy nhiên, nếu logic Frame Buffer phụ thuộc vào đúng 640x480 thì phải giữ nguyên.
    // Ở đây ta giữ nguyên 640x480 để đảm bảo tính đúng đắn.
    parameter TEST_WIDTH      = 640;
    parameter TEST_HEIGHT     = 480; 

    // Số lượng frame cần gửi (phải > 10 vì module ov5640_data bỏ 10 frame đầu)
    parameter FRAMES_TO_SEND  = 15; 

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
    // Lưu ý: Đảm bảo bạn đã có module asyn_fifo trong project
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

    always #((CLK_PERIOD / 2)) tb_clk_i = ~tb_clk_i;
    always #((CLK50_PERIOD / 2)) tb_clk50MHz_i = ~tb_clk50MHz_i;
    always #((CLK25_PERIOD / 2)) tb_clk25MHz_i = ~tb_clk25MHz_i;
    always #((CAM_PCLK_PERIOD / 2)) tb_cam_pclk_i = ~tb_cam_pclk_i;

    //================================================================
    // Main Test Sequence
    //================================================================
    
    integer frame_cnt;

    initial begin
        // --- 1. Initialize Inputs ---
        tb_clk_i              <= 1'b1;
        tb_clk25MHz_i         <= 1'b1;
        tb_clk50MHz_i         <= 1'b1;
        tb_cam_pclk_i         <= 1'b0;
        
        tb_resetn_i           <= 1'b0; 
        tb_cam_half_pixel_i   <= 8'h00;
        tb_cam_href           <= 1'b0;
        tb_cam_vsync          <= 1'b1; // Idle High
        
        tb_resolution_width_i <= TEST_WIDTH;  
        tb_resolution_depth_i <= TEST_HEIGHT; 

        // --- 2. Apply Reset ---
        #(CLK_PERIOD * 20);
        tb_resetn_i <= 1'b1;   
        #(CLK_PERIOD * 20);

        $display("---------------------------------------------------");
        $display("START SIMULATION");
        $display("Target: Send %d frames to pass the 10-frame drop logic", FRAMES_TO_SEND);
        $display("---------------------------------------------------");

        // --- 3. Send Multiple Frames ---
        for (frame_cnt = 1; frame_cnt <= FRAMES_TO_SEND; frame_cnt = frame_cnt + 1) begin
            $display("[%0t] Dang gui Frame %0d / %0d...", $time, frame_cnt, FRAMES_TO_SEND);
            send_frame(TEST_WIDTH, TEST_HEIGHT, frame_cnt);
        end

        $display("[%0t] Da gui xong tat ca cac frame.", $time);

        // Chờ thêm một chút để quan sát đầu ra cuối cùng
        #(CLK_PERIOD * 1000);
        $display("---------------------------------------------------");
        $display("SIMULATION FINISHED");
        $finish;
    end

    //================================================================
    // Monitor Output Process
    //================================================================
    // Block này chạy song song để kiểm tra xem khi nào đầu ra có tín hiệu
    initial begin
        wait(tb_resetn_i == 1'b1); // Chờ reset xong
        forever begin
            @(posedge tb_clk25MHz_i);
            if (tb_dataEnable == 1'b1) begin
                $display("\n>>> SUCCESS: Phat hien DATA ENABLE tai thoi diem %0t", $time);
                $display(">>> RGB Data Output: %h \n", tb_RGBchannel);
                // Sau khi phát hiện dữ liệu ra lần đầu, ta có thể break hoặc tiếp tục monitor
                // disable fork; // Nếu muốn dừng monitor
            end
        end
    end

    //================================================================
    // Task: send_frame
    //================================================================
    task send_frame;
        input integer WIDTH;
        input integer HEIGHT;
        input integer FRAME_NUM; // Để hiển thị màu khác nhau cho mỗi frame
        
        integer i, j;
        reg [7:0] base_color;

        begin
            // Đổi màu nền cơ bản theo số thứ tự frame để dễ debug trên Waveform
            base_color = FRAME_NUM * 10; 

            // --- 1. VSYNC Start (Vertical Blanking) ---
            tb_cam_vsync <= 1'b1;
            tb_cam_href  <= 1'b0;
            repeat(100) @(posedge tb_cam_pclk_i); 
            
            // VSYNC Falling Edge -> Start Frame
            tb_cam_vsync <= 1'b0;
            repeat(50) @(posedge tb_cam_pclk_i); // Back porch ngắn

            // --- 2. Loop Rows ---
            for (i = 0; i < HEIGHT; i = i + 1) begin
                
                // H-Front Porch (Ngắn để sim nhanh)
                tb_cam_href <= 1'b0;
                repeat(5) @(posedge tb_cam_pclk_i); 

                // Active Line
                tb_cam_href <= 1'b1;
                
                // Gửi WIDTH pixel (mỗi pixel 2 byte: High byte sau đó Low byte)
                for (j = 0; j < WIDTH; j = j + 1) begin
                    // Byte Cao (R + G_high)
                    @(posedge tb_cam_pclk_i);
                    tb_cam_half_pixel_i <= base_color + 8'hAA; // Pattern

                    // Byte Thấp (G_low + B)
                    @(posedge tb_cam_pclk_i);
                    tb_cam_half_pixel_i <= (j[7:0]); // Gradient theo chiều ngang
                end
                
                // H-Back Porch
                tb_cam_href <= 1'b0;
                repeat(5) @(posedge tb_cam_pclk_i); 
                
            end 

            // --- 3. VSYNC End ---
            tb_cam_vsync <= 1'b1; // Rising Edge -> End Frame
            repeat(100) @(posedge tb_cam_pclk_i);

        end
    endtask

    // Dump waves for GTKWave / Vivado
    initial begin
        $dumpfile("tb_DVP_RX_TX_core3.vcd");
        $dumpvars(0, tb_DVP_RX_TX_core3); 
    end

endmodule

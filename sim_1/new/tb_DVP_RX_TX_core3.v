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

    // ... (Giữ nguyên các Parameters cũ) ...
    parameter DATA_WIDTH        = 8;
    parameter TEST_WIDTH        = 640;
    parameter TEST_HEIGHT       = 480; 
    parameter FRAMES_TO_SEND    = 12; // Lưu ý: Chỉ cần frame cuối cùng để convert ảnh cho đỡ nặng file

    //================================================================
    // Thêm bộ nhớ và File Handling
    //================================================================
    reg [15:0] image_mem [0:TEST_WIDTH*TEST_HEIGHT-1]; // Chứa ảnh RGB565 nạp từ Python
    integer f_out; // File handler để lưu kết quả đầu ra

    // ... (Giữ nguyên các Signals cũ) ...
    reg tb_clk_i;
    reg tb_clk25MHz_i;
    reg tb_clk50MHz_i;
    reg tb_resetn_i;
    reg tb_cam_pclk_i;
    reg [DATA_WIDTH-1:0] tb_cam_half_pixel_i;
    reg tb_cam_href;
    reg tb_cam_vsync;
    reg [15:0] tb_resolution_width_i;
    reg [15:0] tb_resolution_depth_i;

    wire tb_hsync, tb_vsync, tb_dataEnable, tb_vgaClock;
    wire [23:0] tb_RGBchannel;

    //================================================================
    // Instantiate DUT
    //================================================================
    DVP_RX_TX_core #( .DATA_WIDTH(DATA_WIDTH) /*... giữ các param khác ...*/ )
    uut (
        .clk_i(tb_clk_i), .clk25MHz_i(tb_clk25MHz_i), .clk50MHz_i(tb_clk50MHz_i), .resetn_i(tb_resetn_i),
        .cam_pclk_i(tb_cam_pclk_i), .cam_half_pixel_i(tb_cam_half_pixel_i), 
        .cam_href(tb_cam_href), .cam_vsync(tb_cam_vsync),
        .hsync(tb_hsync), .vsync(tb_vsync), .dataEnable(tb_dataEnable),
        .vgaClock(tb_vgaClock), .RGBchannel(tb_RGBchannel),
        .resolution_width_i(tb_resolution_width_i), .resolution_depth_i(tb_resolution_depth_i)
    );

    // Clock Generation (Giữ nguyên)
    always #5  tb_clk_i = ~tb_clk_i;
    always #20 tb_clk25MHz_i = ~tb_clk25MHz_i;
    always #10 tb_clk50MHz_i = ~tb_clk50MHz_i;
    always #20 tb_cam_pclk_i = ~tb_cam_pclk_i;

    //================================================================
    // Logic Capture Output (Ghi dữ liệu sau xử lý ra file)
    //================================================================
    initial begin
        f_out = $fopen("output_sim.hex", "w");
        if (f_out == 0) begin
            $display("error ko the tao file file output_sim.hex");
            $finish;
        end
    end


    //================================================================
    // Logic Capture Output: Chỉ ghi Frame thứ 11 (sau khi bỏ 10 frame đầu)
    //================================================================
    integer out_frame_cnt = 0;
    reg capturing = 0;

    // 1. Đếm số Frame xuất hiện ở đầu ra dựa vào cạnh xuống của VSYNC
    always @(negedge tb_vsync) begin
        if (tb_resetn_i) begin
            out_frame_cnt = out_frame_cnt + 1;
            $display(">>> He thong da xuat xong Frame dau ra thu: %0d", out_frame_cnt);
            
            // Nếu là Frame thứ 11, bắt đầu cho phép ghi
            if (out_frame_cnt == FRAMES_TO_SEND) begin
                capturing = 1;
                $display(">>> BAT DAU ghi Frame vao file output_sim.hex...");
            end else begin
                capturing = 0;
            end
        end
    end

    // Ghi dữ liệu khi dataEnable = 1 tại mỗi cạnh lên vgaClock
    always @(posedge tb_vgaClock) begin
        if (capturing && tb_dataEnable) begin
            $fwrite(f_out, "%06x\n", tb_RGBchannel);
            $fflush(f_out); // QUAN TRỌNG: Ghi du lieu xuong file ngay lap tuc
        end
    end

    //================================================================
    // Main Test Sequence
    //================================================================
    integer frame_cnt;

    initial begin
        // --- Nạp dữ liệu ảnh từ file hex ---
        $readmemh("image_data.hex", image_mem);
        
        // Khởi tạo các tín hiệu
        tb_clk_i = 1; tb_clk25MHz_i = 1; tb_clk50MHz_i = 1; tb_cam_pclk_i = 0;
        tb_resetn_i = 0; tb_cam_half_pixel_i = 0; tb_cam_href = 0; tb_cam_vsync = 1;
        tb_resolution_width_i = TEST_WIDTH; tb_resolution_depth_i = TEST_HEIGHT;

        #(200);
        tb_resetn_i = 1; 
        #(200);

        $display("START SIMULATION - include file hex to module...");

        for (frame_cnt = 1; frame_cnt <= FRAMES_TO_SEND; frame_cnt = frame_cnt + 1) begin
            $display("Sending Frame %0d...", frame_cnt);
            send_frame_from_mem();
        end

        #(1000);
        $fclose(f_out);
        $display("SIMULATION FINISHED - output_sim.hex");
        $finish;
    end

    //================================================================
    // Task: Gửi dữ liệu ảnh thực tế từ Memory
    //================================================================
    task send_frame_from_mem;
        integer x, y, pixel_idx;
        reg [15:0] current_pixel;
        begin
            pixel_idx = 0;
            // VSYNC Start: High trong khoảng 3 dòng (HTS * 3)
            tb_cam_vsync <= 1'b1;
            repeat(1896 * 3) @(posedge tb_cam_pclk_i);
            tb_cam_vsync <= 1'b0;
            
            // Vertical Back Porch (Ví dụ 10 dòng)
            repeat(1896 * 10) @(posedge tb_cam_pclk_i);

            for (y = 0; y < 480; y = y + 1) begin
                // H-Front Porch (Ví dụ 20 PCLK)
                tb_cam_href <= 1'b0;
                repeat(20) @(posedge tb_cam_pclk_i);

                tb_cam_href <= 1'b1;
                for (x = 0; x < 640; x = x + 1) begin
                    current_pixel = image_mem[pixel_idx];
                    tb_cam_half_pixel_i <= current_pixel[15:8]; // Byte cao
                    @(posedge tb_cam_pclk_i);
                    tb_cam_half_pixel_i <= current_pixel[7:0];  // Byte thấp
                    @(posedge tb_cam_pclk_i);
                    pixel_idx = pixel_idx + 1;
                end
                tb_cam_href <= 1'b0;
                
                // H-Blanking còn lại: 1896 - 1280 - 20 = 596
                repeat(596) @(posedge tb_cam_pclk_i); 
            end
            
            tb_cam_vsync <= 1'b1;
            repeat(1896 * 10) @(posedge tb_cam_pclk_i); // Vertical Front Porch
        end
    endtask

endmodule
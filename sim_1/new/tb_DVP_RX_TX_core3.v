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
    // 1. PARAMETERS & CONFIGURATION
    //================================================================
    parameter DATA_WIDTH   = 8;
    parameter TEST_WIDTH   = 640;
    parameter TEST_HEIGHT  = 480;
    parameter NUM_IMAGES   = 20; 

    string INPUT_PATH  = "/home/raven1911/Data/vivado_prj/VIDEO_SYSTEM_HDL/VIDEO_SYSTEM_HDL.srcs/python_programs/output_images/";
    string OUTPUT_PATH = "/home/raven1911/Data/vivado_prj/VIDEO_SYSTEM_HDL/VIDEO_SYSTEM_HDL.srcs/python_programs/output_testbench/";

    //================================================================
    // 2. SIGNALS & VARIABLE DECLARATIONS (Đã sửa lỗi tại đây)
    //================================================================
    reg tb_clk_i, tb_clk25MHz_i, tb_clk50MHz_i, tb_resetn_i, tb_cam_pclk_i;
    reg [DATA_WIDTH-1:0] tb_cam_half_pixel_i;
    reg tb_cam_href, tb_cam_vsync;
    reg [15:0] tb_resolution_width_i, tb_resolution_depth_i;

    wire tb_hsync, tb_vsync, tb_dataEnable, tb_vgaClock;
    wire [23:0] tb_RGBchannel;

    reg [15:0] image_mem [0:TEST_WIDTH*TEST_HEIGHT-1];
    
    // Khai báo biến toàn cục trong module để tránh lỗi VRFC 10-4982
    integer f_out = 0;
    integer global_vsync_cnt = 0; 
    integer out_img_idx = 0;      
    string out_name; // Khai báo tại đây
    string in_name;  // Khai báo tại đây

    //================================================================
    // 3. DUT INSTANTIATION
    //================================================================
    DVP_RX_TX_core #(.DATA_WIDTH(DATA_WIDTH)) uut (
        .clk_i(tb_clk_i), .clk25MHz_i(tb_clk25MHz_i), .clk50MHz_i(tb_clk50MHz_i), .resetn_i(tb_resetn_i),
        .cam_pclk_i(tb_cam_pclk_i), .cam_half_pixel_i(tb_cam_half_pixel_i), 
        .cam_href(tb_cam_href), .cam_vsync(tb_cam_vsync),
        .hsync(tb_hsync), .vsync(tb_vsync), .dataEnable(tb_dataEnable),
        .vgaClock(tb_vgaClock), .RGBchannel(tb_RGBchannel),
        .resolution_width_i(tb_resolution_width_i), .resolution_depth_i(tb_resolution_depth_i)
    );

    // Clock Generation
    initial begin tb_clk_i=1; tb_clk25MHz_i=1; tb_clk50MHz_i=1; tb_cam_pclk_i=0; end
    always #2.5 tb_clk_i = ~tb_clk_i; 
    always #20 tb_clk25MHz_i = ~tb_clk25MHz_i;
    always #10 tb_clk50MHz_i = ~tb_clk50MHz_i;
    always #10 tb_cam_pclk_i = ~tb_cam_pclk_i; //50MHz

    //================================================================
    // 4. LOGIC GHI (CATCHER): CHỈ ĐỢI 5 LẦN ĐẦU RỒI GHI LIÊN TỤC
    //================================================================
    always @(negedge tb_vsync) begin
        if (tb_resetn_i) begin
            // Chỉ bắt đầu mở file từ frame đầu ra thứ 6 (sau 5 frame trễ)
            if (global_vsync_cnt >= 4) begin
                if (f_out != 0) $fclose(f_out);
                
                // Gán giá trị cho out_name đã khai báo ở trên
                out_name = $sformatf("%soutput_%0d.hex", OUTPUT_PATH, out_img_idx);
                f_out = $fopen(out_name, "w");
                
                $display(">>> [CATCHER] Dang mo file output: %s", out_name);
                
                // Quay vòng index từ 0-19
                if (out_img_idx == NUM_IMAGES - 1) out_img_idx <= 0;
                else out_img_idx <= out_img_idx + 1;
            end
            
            global_vsync_cnt <= global_vsync_cnt + 1;
        end
    end

    // Ghi dữ liệu khi file đang mở
    always @(posedge tb_vgaClock) begin
        if (f_out != 0 && tb_dataEnable) begin
            $fwrite(f_out, "%06x\n", tb_RGBchannel);
        end
    end

    //================================================================
    // 5. CHU TRÌNH GỬI (FEEDER): GỬI LIÊN TỤC 20 ẢNH
    //================================================================
    initial begin
        tb_resetn_i = 0; tb_cam_half_pixel_i = 0; tb_cam_href = 0; tb_cam_vsync = 1;
        tb_resolution_width_i = TEST_WIDTH; tb_resolution_depth_i = TEST_HEIGHT;
        #200; tb_resetn_i = 1; #200;

        $display("--- BAT DAU GUI LUONG ANH CAMERA ---");

        forever begin
            for (integer i = 0; i < NUM_IMAGES; i = i + 1) begin
                // Gán giá trị cho in_name đã khai báo ở trên
                in_name = $sformatf("%sinput_image%0d.hex", INPUT_PATH, i);
                $readmemh(in_name, image_mem);
                
                $display(">> [FEEDER] Dang gui anh: %s", in_name);
                send_one_frame(); 
            end
        end
    end

    // Task gửi 1 frame (640x480)
    task send_one_frame;
        integer x, y, p_idx;
        begin
            p_idx = 0;
            tb_cam_vsync <= 1; repeat(1896*3) @(posedge tb_cam_pclk_i);
            tb_cam_vsync <= 0; repeat(1896*10) @(posedge tb_cam_pclk_i);
            for (y=0; y<480; y=y+1) begin
                tb_cam_href <= 0; repeat(20) @(posedge tb_cam_pclk_i);
                tb_cam_href <= 1;
                for (x=0; x<640; x=x+1) begin
                    tb_cam_half_pixel_i <= image_mem[p_idx][15:8]; @(posedge tb_cam_pclk_i);
                    tb_cam_half_pixel_i <= image_mem[p_idx][7:0];  @(posedge tb_cam_pclk_i);
                    p_idx = p_idx + 1;
                end
                tb_cam_href <= 0; repeat(596) @(posedge tb_cam_pclk_i);
            end
            tb_cam_vsync <= 1; repeat(1896*10) @(posedge tb_cam_pclk_i);
        end
    endtask

endmodule
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

// module tb_DVP_RX_TX_core3;

//     // ... (Giữ nguyên các Parameters cũ) ...
//     parameter DATA_WIDTH        = 8;
//     parameter TEST_WIDTH        = 640;
//     parameter TEST_HEIGHT       = 480; 
//     parameter FRAMES_TO_SEND    = 8; // Lưu ý: Chỉ cần frame cuối cùng để convert ảnh cho đỡ nặng file

//     //================================================================
//     // Thêm bộ nhớ và File Handling
//     //================================================================
//     reg [15:0] image_mem [0:TEST_WIDTH*TEST_HEIGHT-1]; // Chứa ảnh RGB565 nạp từ Python
//     integer f_out; // File handler để lưu kết quả đầu ra

//     // ... (Giữ nguyên các Signals cũ) ...
//     reg tb_clk_i;
//     reg tb_clk25MHz_i;
//     reg tb_clk50MHz_i;
//     reg tb_resetn_i;
//     reg tb_cam_pclk_i;
//     reg [DATA_WIDTH-1:0] tb_cam_half_pixel_i;
//     reg tb_cam_href;
//     reg tb_cam_vsync;
//     reg [15:0] tb_resolution_width_i;
//     reg [15:0] tb_resolution_depth_i;

//     wire tb_hsync, tb_vsync, tb_dataEnable, tb_vgaClock;
//     wire [23:0] tb_RGBchannel;

//     //================================================================
//     // Instantiate DUT
//     //================================================================
//     DVP_RX_TX_core #( .DATA_WIDTH(DATA_WIDTH) /*... giữ các param khác ...*/ )
//     uut (
//         .clk_i(tb_clk_i), .clk25MHz_i(tb_clk25MHz_i), .clk50MHz_i(tb_clk50MHz_i), .resetn_i(tb_resetn_i),
//         .cam_pclk_i(tb_cam_pclk_i), .cam_half_pixel_i(tb_cam_half_pixel_i), 
//         .cam_href(tb_cam_href), .cam_vsync(tb_cam_vsync),
//         .hsync(tb_hsync), .vsync(tb_vsync), .dataEnable(tb_dataEnable),
//         .vgaClock(tb_vgaClock), .RGBchannel(tb_RGBchannel),
//         .resolution_width_i(tb_resolution_width_i), .resolution_depth_i(tb_resolution_depth_i)
//     );

//     // Clock Generation (Giữ nguyên)
//     always #3.335  tb_clk_i = ~tb_clk_i;
//     always #20 tb_clk25MHz_i = ~tb_clk25MHz_i;
//     always #10 tb_clk50MHz_i = ~tb_clk50MHz_i;
//     always #20 tb_cam_pclk_i = ~tb_cam_pclk_i;

//     //================================================================
//     // Logic Capture Output (Ghi dữ liệu sau xử lý ra file)
//     //================================================================
//     initial begin
//         f_out = $fopen("output_sim.hex", "w");
//         if (f_out == 0) begin
//             $display("error ko the tao file file output_sim.hex");
//             $finish;
//         end
//     end


//     //================================================================
//     // Logic Capture Output: Chỉ ghi Frame thứ 11 (sau khi bỏ 10 frame đầu)
//     //================================================================
//     integer out_frame_cnt = 0;
//     reg capturing = 0;

//     // 1. Đếm số Frame xuất hiện ở đầu ra dựa vào cạnh xuống của VSYNC
//     always @(negedge tb_vsync) begin
//         if (tb_resetn_i) begin
//             out_frame_cnt = out_frame_cnt + 1;
//             $display(">>> He thong da xuat xong Frame dau ra thu: %0d", out_frame_cnt);
            
//             // Nếu là Frame thứ 11, bắt đầu cho phép ghi
//             if (out_frame_cnt == FRAMES_TO_SEND + 2) begin
//                 capturing = 1;
//                 $display(">>> BAT DAU ghi Frame vao file output_sim.hex...");
//             end else begin
//                 capturing = 0;
//             end
//         end
//     end

//     // Ghi dữ liệu khi dataEnable = 1 tại mỗi cạnh lên vgaClock
//     always @(posedge tb_vgaClock) begin
//         if (capturing && tb_dataEnable) begin
//             $fwrite(f_out, "%06x\n", tb_RGBchannel);
//             $fflush(f_out); // QUAN TRỌNG: Ghi du lieu xuong file ngay lap tuc
//         end
//     end

//     //================================================================
//     // Main Test Sequence
//     //================================================================
//     integer frame_cnt;

//     initial begin
//         // --- Nạp dữ liệu ảnh từ file hex ---
//         $readmemh("image_data.hex", image_mem);
        
//         // Khởi tạo các tín hiệu
//         tb_clk_i = 1; tb_clk25MHz_i = 1; tb_clk50MHz_i = 1; tb_cam_pclk_i = 0;
//         tb_resetn_i = 0; tb_cam_half_pixel_i = 0; tb_cam_href = 0; tb_cam_vsync = 1;
//         tb_resolution_width_i = TEST_WIDTH; tb_resolution_depth_i = TEST_HEIGHT;

//         #(200);
//         tb_resetn_i = 1; 
//         #(200);

//         $display("START SIMULATION - include file hex to module...");

//         for (frame_cnt = 1; frame_cnt <= FRAMES_TO_SEND; frame_cnt = frame_cnt + 1) begin
//             $display("Sending Frame %0d...", frame_cnt);
//             send_frame_from_mem();
//         end

//         #(1000);
//         $fclose(f_out);
//         $display("SIMULATION FINISHED - output_sim.hex");
//         $finish;
//     end

//     //================================================================
//     // Task: Gửi dữ liệu ảnh thực tế từ Memory
//     //================================================================
//     task send_frame_from_mem;
//         integer x, y, pixel_idx;
//         reg [15:0] current_pixel;
//         begin
//             pixel_idx = 0;
//             // VSYNC Start: High trong khoảng 3 dòng (HTS * 3)
//             tb_cam_vsync <= 1'b1;
//             repeat(1896 * 3) @(posedge tb_cam_pclk_i);
//             tb_cam_vsync <= 1'b0;
            
//             // Vertical Back Porch (Ví dụ 10 dòng)
//             repeat(1896 * 10) @(posedge tb_cam_pclk_i);

//             for (y = 0; y < 480; y = y + 1) begin
//                 // H-Front Porch (Ví dụ 20 PCLK)
//                 tb_cam_href <= 1'b0;
//                 repeat(20) @(posedge tb_cam_pclk_i);

//                 tb_cam_href <= 1'b1;
//                 for (x = 0; x < 640; x = x + 1) begin
//                     current_pixel = image_mem[pixel_idx];
//                     tb_cam_half_pixel_i <= current_pixel[15:8]; // Byte cao
//                     @(posedge tb_cam_pclk_i);
//                     tb_cam_half_pixel_i <= current_pixel[7:0];  // Byte thấp
//                     @(posedge tb_cam_pclk_i);
//                     pixel_idx = pixel_idx + 1;
//                 end
//                 tb_cam_href <= 1'b0;
                
//                 // H-Blanking còn lại: 1896 - 1280 - 20 = 596
//                 repeat(596) @(posedge tb_cam_pclk_i); 
//             end
            
//             tb_cam_vsync <= 1'b1;
//             repeat(1896 * 10) @(posedge tb_cam_pclk_i); // Vertical Front Porch
//         end
//     endtask

// endmodule



// module tb_DVP_RX_TX_core3;

//     //================================================================
//     // 1. PARAMETERS & CONFIGURATION
//     //================================================================
//     parameter DATA_WIDTH   = 8;
//     parameter TEST_WIDTH   = 640;
//     parameter TEST_HEIGHT  = 480;
//     parameter NUM_IMAGES   = 20; // Xử lý 20 ảnh
    
//     // ĐƯỜNG DẪN THƯ MỤC (Lưu ý dùng dấu "/" thay vì "\" để tránh lỗi Windows path)
//     // Hãy sửa các đường dẫn này cho đúng với folder của bạn
//     string INPUT_PATH  = "D:/verilog_projects/VIDEO_SYSTEM_HDL/VIDEO_SYSTEM_HDL.srcs/sources_1/python_programs/output_images/";
//     string OUTPUT_PATH = "D:/verilog_projects/VIDEO_SYSTEM_HDL/VIDEO_SYSTEM_HDL.srcs/sources_1/python_programs/output_testbench/";
//     //================================================================
//     // 2. SIGNALS
//     //================================================================
//     reg tb_clk_i;
//     reg tb_clk25MHz_i;
//     reg tb_clk50MHz_i;
//     reg tb_resetn_i;
//     reg tb_cam_pclk_i;
//     reg [DATA_WIDTH-1:0] tb_cam_half_pixel_i;
//     reg tb_cam_href;
//     reg tb_cam_vsync;
//     reg [15:0] tb_resolution_width_i;
//     reg [15:0] tb_resolution_depth_i;

//     wire tb_hsync, tb_vsync, tb_dataEnable, tb_vgaClock;
//     wire [23:0] tb_RGBchannel;

//     // Bộ nhớ để nạp ảnh hiện tại
//     reg [15:0] image_mem [0:TEST_WIDTH*TEST_HEIGHT-1];
//     integer f_out;
//     integer img_idx;
//     string current_input_file;
//     string current_output_file;
//     reg capturing = 0;

//     integer out_frame_cnt = 0; // Đếm số frame xuất hiện ở đầu ra
//     integer pixel_count = 0;

//     //================================================================
//     // 3. DUT INSTANTIATION
//     //================================================================
//     DVP_RX_TX_core #(
//         .DATA_WIDTH(DATA_WIDTH)
//     ) uut (
//         .clk_i(tb_clk_i),
//         .clk25MHz_i(tb_clk25MHz_i),
//         .clk50MHz_i(tb_clk50MHz_i),
//         .resetn_i(tb_resetn_i),
//         .cam_pclk_i(tb_cam_pclk_i),
//         .cam_half_pixel_i(tb_cam_half_pixel_i), 
//         .cam_href(tb_cam_href),
//         .cam_vsync(tb_cam_vsync),
//         .hsync(tb_hsync),
//         .vsync(tb_vsync),
//         .dataEnable(tb_dataEnable),
//         .vgaClock(tb_vgaClock),
//         .RGBchannel(tb_RGBchannel),
//         .resolution_width_i(tb_resolution_width_i),
//         .resolution_depth_i(tb_resolution_depth_i)
//     );

//     //================================================================
//     // 4. CLOCK GENERATION
//     //================================================================
//     initial tb_clk_i = 1;
//     always #3.335 tb_clk_i = ~tb_clk_i;

//     initial tb_clk25MHz_i = 1;
//     always #20 tb_clk25MHz_i = ~tb_clk25MHz_i;

//     initial tb_clk50MHz_i = 1;
//     always #10 tb_clk50MHz_i = ~tb_clk50MHz_i;

//     initial tb_cam_pclk_i = 0;
//     always #20 tb_cam_pclk_i = ~tb_cam_pclk_i;

//     integer vsync_count = 0;   // Bộ đếm vsync
//     integer pixel_count = 0;   // Bộ đếm pixel để dừng sau 1 frame
//     reg capturing = 0;
//     // 1. Đếm số lần tb_vsync xuất hiện ở đầu ra
//     always @(negedge tb_vsync) begin
//         if (tb_resetn_i) begin
//             vsync_count <= vsync_count + 1;
//         end
//     end
//     // 2. Ghi dữ liệu dựa trên bộ đếm vsync
//     always @(posedge tb_vgaClock) begin
//         // Sau khi thấy 5 lần vsync, và dataEnable bắt đầu lên ở lần thứ 6
//         if (vsync_count >= 5 && tb_dataEnable && !capturing) begin
//             capturing <= 1;
//             pixel_count <= 0;
//             $display(">>> [CAPTURE] Bat dau ghi Frame cho anh %0d...", img_idx);
//         end

//         if (capturing && tb_dataEnable) begin
//             $fwrite(f_out, "%06x\n", tb_RGBchannel);
//             pixel_count <= pixel_count + 1;

//             // Dừng sau khi ghi đủ 1 frame (640x480)
//             if (pixel_count >= (TEST_WIDTH * TEST_HEIGHT) - 1) begin
//                 capturing <= 0;
//                 $display(">>> [CAPTURE] Da xong Frame anh %0d.", img_idx);
//             end
//         end
//     end
//     // //================================================================
//     // // 5. DATA CAPTURE LOGIC
//     // //================================================================
//     // always @(posedge tb_vgaClock) begin
//     //     if (capturing && tb_dataEnable) begin
//     //         $fwrite(f_out, "%06x\n", tb_RGBchannel);
//     //     end
//     // end

//     //================================================================
//     // 6. MAIN SIMULATION SEQUENCE
//     //================================================================
//     initial begin
//         // Khởi tạo trạng thái ban đầu
//         tb_resetn_i = 0;
//         tb_cam_half_pixel_i = 0;
//         tb_cam_href = 0;
//         tb_cam_vsync = 1;
//         tb_resolution_width_i = TEST_WIDTH;
//         tb_resolution_depth_i = TEST_HEIGHT;

//         #(200);
//         tb_resetn_i = 1;
//         #(200);

//         $display("--- BAT DAU CHUYEN DOI BATCH: %0d ANH ---", NUM_IMAGES);

//         // Vòng lặp duyệt qua 20 ảnh
//         for (img_idx = 0; img_idx < NUM_IMAGES; img_idx = img_idx + 1) begin
            
//             // Tạo đường dẫn file input/output động
//             current_input_file  = $sformatf("%sinput_image%0d.hex", INPUT_PATH, img_idx);
//             current_output_file = $sformatf("%soutput_%0d.hex", OUTPUT_PATH, img_idx);

//             // Nạp dữ liệu vào bộ nhớ
//             $readmemh(current_input_file, image_mem);
//             $display(">> [%0t] Dang xu ly: %s", $time, current_input_file);

//             // Mở file output để ghi
//             f_out = $fopen(current_output_file, "w");
//             if (f_out == 0) begin
//                 $display("--- LOI: Khong the tao file %s ---", current_output_file);
//                 $finish;
//             end

//             // Gửi Frame qua module
//             // capturing = 1; // Bật cờ cho phép ghi dữ liệu đầu ra
//             send_frame_from_mem();
//             // capturing = 0;

//             // Đóng file và nghỉ giữa các frame
//             $fclose(f_out);
//             $display(">> [%0t] Da luu xong: %s", $time, current_output_file);
//             #(10000); 
//         end

//         $display("--- HOAN THANH TAT CA 20 ANH ---");
//         $finish;
//     end

//     //================================================================
//     // 7. TASK: SEND DVP FRAME
//     //================================================================
//     task send_frame_from_mem;
//         integer x, y, pixel_idx;
//         reg [15:0] current_pixel;
//         begin
//             pixel_idx = 0;
//             // VSYNC Pulse (Active High)
//             tb_cam_vsync <= 1'b1;
//             repeat(1896 * 3) @(posedge tb_cam_pclk_i);
//             tb_cam_vsync <= 1'b0;
            
//             // Vertical Back Porch
//             repeat(1896 * 10) @(posedge tb_cam_pclk_i);

//             for (y = 0; y < TEST_HEIGHT; y = y + 1) begin
//                 // H-Front Porch
//                 tb_cam_href <= 1'b0;
//                 repeat(20) @(posedge tb_cam_pclk_i);

//                 tb_cam_href <= 1'b1;
//                 for (x = 0; x < TEST_WIDTH; x = x + 1) begin
//                     current_pixel = image_mem[pixel_idx];
//                     // Gửi byte cao trước (DVP 8-bit bus cho RGB565)
//                     tb_cam_half_pixel_i <= current_pixel[15:8]; 
//                     @(posedge tb_cam_pclk_i);
//                     // Gửi byte thấp sau
//                     tb_cam_half_pixel_i <= current_pixel[7:0];  
//                     @(posedge tb_cam_pclk_i);
//                     pixel_idx = pixel_idx + 1;
//                 end
//                 tb_cam_href <= 1'b0;
                
//                 // H-Blanking
//                 repeat(596) @(posedge tb_cam_pclk_i); 
//             end
            
//             // Vertical Front Porch
//             tb_cam_vsync <= 1'b1;
//             repeat(1896 * 10) @(posedge tb_cam_pclk_i);
//         end
//     endtask

// endmodule
`timescale 1ns / 1ps

module tb_DVP_RX_TX_core3;

    //================================================================
    // 1. PARAMETERS & CONFIGURATION
    //================================================================
    parameter DATA_WIDTH   = 8;
    parameter TEST_WIDTH   = 640;
    parameter TEST_HEIGHT  = 480;
    parameter NUM_IMAGES   = 20; 

    string INPUT_PATH  = "D:/verilog_projects/VIDEO_SYSTEM_HDL/VIDEO_SYSTEM_HDL.srcs/sources_1/python_programs/output_images/";
    string OUTPUT_PATH = "D:/verilog_projects/VIDEO_SYSTEM_HDL/VIDEO_SYSTEM_HDL.srcs/sources_1/python_programs/output_testbench/";

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
    always #5 tb_clk_i = ~tb_clk_i; //3.335
    always #20 tb_clk25MHz_i = ~tb_clk25MHz_i;
    always #10 tb_clk50MHz_i = ~tb_clk50MHz_i;
    always #20 tb_cam_pclk_i = ~tb_cam_pclk_i;

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
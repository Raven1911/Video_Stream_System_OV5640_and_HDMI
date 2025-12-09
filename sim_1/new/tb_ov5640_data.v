`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/03/2025 04:03:54 PM
// Design Name: 
// Module Name: tb_ov5640_data
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

module tb_ov5640_data();

    // Tín hiệu
    reg             sys_rst_n;
    reg             ov5640_pclk;
    reg             ov5640_href;
    reg             ov5640_vsync;
    reg     [7:0]   ov5640_data;

    wire            ov5640_wr_en;
    wire    [15:0]  ov5640_data_out;

    // Tham số
    parameter PCLK_PERIOD = 20; // 50MHz
    integer frame_cnt = 0;      // Biến đếm frame trong testbench
    integer i;

    // DUT
    ov5640_data u_ov5640_data (
        .sys_rst_n       (sys_rst_n),
        .ov5640_pclk     (ov5640_pclk),
        .ov5640_href     (ov5640_href),
        .ov5640_vsync    (ov5640_vsync),
        .ov5640_data     (ov5640_data),
        .ov5640_wr_en    (ov5640_wr_en),
        .ov5640_data_out (ov5640_data_out)
    );

    // Tạo Clock
    initial begin
        ov5640_pclk = 0;
        forever #(PCLK_PERIOD/2) ov5640_pclk = ~ov5640_pclk;
    end

    // --- TASK: Mô phỏng 1 Frame ảnh ---
    task simulate_one_frame;
        input [7:0] frame_idx; // Số thứ tự frame để in ra màn hình
        begin
            // 1. Tạo xung VSYNC (Báo hiệu bắt đầu frame)
            ov5640_vsync = 1;
            #(PCLK_PERIOD * 100); // VSYNC giữ mức cao một lúc
            ov5640_vsync = 0;
            #(PCLK_PERIOD * 50);  // Back porch

            // 2. Gửi dữ liệu giả lập (Chỉ gửi 2 dòng cho nhanh)
            // Dòng 1
            ov5640_href = 1;
            for(i=0; i<4; i=i+1) begin
                ov5640_data = 8'hA0 + i; @(posedge ov5640_pclk); // Byte cao
                ov5640_data = 8'h50 + i; @(posedge ov5640_pclk); // Byte thấp
            end
            ov5640_href = 0;
            #(PCLK_PERIOD * 10);
            
            // Dòng 2
            ov5640_href = 1;
            for(i=0; i<4; i=i+1) begin
                ov5640_data = 8'hB0 + i; @(posedge ov5640_pclk);
                ov5640_data = 8'h60 + i; @(posedge ov5640_pclk);
            end
            ov5640_href = 0;
            ov5640_data = 0;
            
            #(PCLK_PERIOD * 200); // Thời gian nghỉ hết frame
            
            // 3. Kiểm tra kết quả ngay trong Task
            if (frame_idx <= 10) begin
                if (ov5640_wr_en == 0) 
                    $display("Time %t | Frame %d: OK (Data bi bo qua)", $time, frame_idx);
                else 
                    $display("Time %t | Frame %d: FAIL (Du lieu xuat hien qua som!)", $time, frame_idx);
            end else begin
                // Frame 11 trở đi phải có data
                // Kiểm tra đơn giản: data_out phải khác 0 ở một thời điểm nào đó, nhưng check thủ công trên wave dễ hơn
                $display("Time %t | Frame %d: Dang xuat du lieu...", $time, frame_idx);
            end
        end
    endtask

    // --- MAIN STIMULUS ---
    initial begin
        // Khởi tạo
        sys_rst_n = 0;
        ov5640_href = 0;
        ov5640_vsync = 0;
        ov5640_data = 0;

        // Reset
        #(PCLK_PERIOD * 10);
        sys_rst_n = 1;
        #(PCLK_PERIOD * 10);

        $display("-------------------------------------------");
        $display("START SIMULATION: Testing 10 Frames Drop");
        $display("-------------------------------------------");

        // Chạy vòng lặp 15 frame
        for (frame_cnt = 1; frame_cnt <= 15; frame_cnt = frame_cnt + 1) begin
            simulate_one_frame(frame_cnt);
        end

        $display("-------------------------------------------");
        $display("SIMULATION FINISHED");
        $stop;
    end

endmodule
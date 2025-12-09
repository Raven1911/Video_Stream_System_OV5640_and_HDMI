`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/25/2025 05:25:33 PM
// Design Name: 
// Module Name: tb_vgaHDMI_interface3
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


module tb_vgaHDMI_interface3;

    // =========================
    // 1. Khai báo tín hiệu
    // =========================
    
    // Inputs cho DUT (Device Under Test)
    reg clock25;
    reg clock50;
    reg resetn;
    reg empty_fifo;
    reg [15:0] fifo_data_in;

    // Outputs từ DUT
    wire fifo_read_en;
    wire hsync;
    wire vsync;
    wire dataEnable;
    wire vgaClock;
    wire [23:0] RGBchannel;

    // =========================
    // 2. Khởi tạo DUT (Module cần test)
    // =========================
    vgaHDMI_interface3 dut (
        .clock25(clock25),
        .clock50(clock50),
        .resetn(resetn),
        .empty_fifo(empty_fifo),
        .fifo_data_in(fifo_data_in),
        .fifo_read_en(fifo_read_en),
        .hsync(hsync),
        .vsync(vsync),
        .dataEnable(dataEnable),
        .vgaClock(vgaClock),
        .RGBchannel(RGBchannel)
    );

    // =========================
    // 3. Tạo Clock
    // =========================
    
    // Tạo clock 50MHz (Chu kỳ 20ns)
    initial begin
        clock50 = 0;
        forever #10 clock50 = ~clock50;
    end

    // Tạo clock 25MHz (Chu kỳ 40ns)
    // Lưu ý: Trong thực tế, clock25 thường được chia từ clock50 hoặc PLL.
    // Ở đây ta tạo độc lập nhưng đồng bộ pha ban đầu.
    initial begin
        clock25 = 0;
        forever #20 clock25 = ~clock25;
    end

    // =========================
    // 4. Logic giả lập FIFO
    // =========================
    
    // Mỗi khi module yêu cầu đọc (fifo_read_en = 1), 
    // ta đổi dữ liệu đầu vào ở cạnh lên tiếp theo của clock để giả lập FIFO thật.
    always @(posedge clock25) begin
        if (!resetn) begin
            fifo_data_in <= 16'h0000; // Reset dữ liệu
        end else if (fifo_read_en) begin
            // Tạo pattern màu: Tăng giá trị để thấy màu thay đổi trên waveform
            fifo_data_in <= fifo_data_in + 16'h0001; 
        end
    end

    // =========================
    // 5. Quy trình Test (Stimulus)
    // =========================
    initial begin
        // --- Khởi tạo ---
        resetn = 0;
        empty_fifo = 1;     // Giả sử FIFO đang rỗng
        fifo_data_in = 16'hF800; // Màu đỏ (Red trong RGB565) làm mẫu đầu tiên

        // --- Reset hệ thống ---
        #100;
        resetn = 1;         // Thả reset
        $display("Time: %t - System Reset Released", $time);

        // --- Chờ module khởi động ---
        // Module của bạn có trạng thái DELAY chờ pixel_x/y chạy.
        // Ta chờ khoảng 1 thời gian ngắn để counter bắt đầu đếm.
        #1000;

        // --- Giả lập FIFO có dữ liệu ---
        // Khi FIFO không rỗng, FSM sẽ chuyển từ IDLE -> DISPLAY (hoặc xử lý dữ liệu)
        empty_fifo = 0; 
        $display("Time: %t - FIFO is now NOT empty, data streaming starts", $time);

        // --- Chạy mô phỏng ---
        // Một khung hình 640x480 @ 60Hz mất khoảng 16.6ms.
        // Để tiết kiệm thời gian mô phỏng, ta chạy đủ lâu để thấy HSYNC và Data Enable
        // Chạy khoảng 2 dòng quét (800 clocks * 40ns * 2 dòng = 64000ns)
        
        #200000; // Chạy 200us
        
        // Kiểm tra xem VSYNC có hoạt động không (cần chạy rất lâu hoặc ép counter)
        // Ở đây ta dừng để xem waveform cơ bản.
        
        $display("Time: %t - Simulation Finished", $time);
        $stop;
    end

    // =========================
    // 6. Monitor (Tùy chọn: In ra console)
    // =========================
    initial begin
        $monitor("Time: %t | X:%d Y:%d | DE:%b | READ:%b | RGB:%h", 
                 $time, dut.m0.pixel_x, dut.m0.pixel_y, dataEnable, fifo_read_en, RGBchannel);
    end

endmodule
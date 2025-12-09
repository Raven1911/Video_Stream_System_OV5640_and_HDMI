`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/19/2025 04:54:53 PM
// Design Name: 
// Module Name: tb_vgaHDMI_interface2
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


module tb_vgaHDMI_interface2;

    // Clock & reset
    reg clock;
    reg clock50;
    reg resetn;

    // FIFO interface
    reg  [15:0] fifo_data_in;
    reg         fifo_empty;
    wire        fifo_read_en;

    // Outputs từ DUT
    wire        hsync;
    wire        vsync;
    wire        dataEnable;
    wire        vgaClock;
    wire [23:0] RGBchannel;

    // ----------------------------------------------------------------
    // DUT instance
    // ----------------------------------------------------------------
    vgaHDMI_interface2 dut (
        .clock       (clock),
        .clock50     (clock50),
        .resetn      (resetn),
        .fifo_data_in(fifo_data_in),
        .fifo_empty  (fifo_empty),
        .hsync       (hsync),
        .vsync       (vsync),
        .dataEnable  (dataEnable),
        .vgaClock    (vgaClock),
        .RGBchannel  (RGBchannel),
        .fifo_read_en(fifo_read_en)
    );

    // ----------------------------------------------------------------
    // Tạo clock: 25MHz và 50MHz
    // ----------------------------------------------------------------
    initial begin
        clock = 1'b0;
        forever #20 clock = ~clock;     // 40ns period -> 25MHz
    end

    initial begin
        clock50 = 1'b0;
        forever #10 clock50 = ~clock50; // 20ns period -> 50MHz
    end

    // ----------------------------------------------------------------
    // VCD dump để xem waveform (GTKWave, v.v.)
    // ----------------------------------------------------------------
    initial begin
        $dumpfile("vgaHDMI_interface_tb.vcd");
        $dumpvars(0, tb_vgaHDMI_interface2);
    end

    // ----------------------------------------------------------------
    // Reset & stimulus chính
    // ----------------------------------------------------------------
    initial begin
        // Khởi tạo
        resetn       = 1'b0;
        fifo_empty   = 1'b1;      // FIFO rỗng ban đầu
        fifo_data_in = 16'h0000;

        // Giữ reset 200ns
        #200;
        resetn = 1'b1;
        $display("[%0t] Release reset", $time);

        // Để module chạy vài ms với FIFO rỗng (khung hình toàn đen)
        // 5ms = 5,000,000ns
        #5_000_000;
        $display("[%0t] FIFO bắt đầu có dữ liệu (fifo_empty=0)", $time);
        fifo_empty = 1'b0;

        // Cho chạy tiếp khoảng 40ms rồi dừng
        #40_000_000;
        $display("[%0t] Kết thúc mô phỏng", $time);
        $finish;
    end

    // ----------------------------------------------------------------
    // Mô phỏng FIFO: gán dữ liệu khi fifo_read_en = 1
    // ----------------------------------------------------------------
    always @(posedge clock or negedge resetn) begin
        if (!resetn) begin
            fifo_data_in <= 16'h0000;
        end else begin
            if (!fifo_empty && fifo_read_en) begin
                // Mỗi lần DUT yêu cầu đọc FIFO thì tăng data
                fifo_data_in <= fifo_data_in + 16'h0001;
            end
        end
    end

    // ----------------------------------------------------------------
    // Đếm số frame dựa trên vsync: mỗi lần vsync lên 1 từ 0 -> coi như frame mới
    // ----------------------------------------------------------------
    reg vsync_d;
    integer frame_count;

    always @(posedge clock or negedge resetn) begin
        if (!resetn) begin
            vsync_d     <= 1'b1;
            frame_count <= 0;
        end else begin
            vsync_d <= vsync;

            // vsync active-low, nên posedge (0->1) là kết thúc xung sync -> frame mới
            if (vsync_d == 1'b0 && vsync == 1'b1) begin
                frame_count <= frame_count + 1;
                $display("[%0t] Frame %0d kết thúc, frame mới bắt đầu", 
                         $time, frame_count);
            end
        end
    end

    // ----------------------------------------------------------------
    // Theo dõi lúc nào bắt đầu có dataEnable (bắt đầu stream)
    // ----------------------------------------------------------------
    reg dataEnable_d;

    always @(posedge clock or negedge resetn) begin
        if (!resetn) begin
            dataEnable_d <= 1'b0;
        end else begin
            dataEnable_d <= dataEnable;

            // Rising edge của dataEnable
            if (!dataEnable_d && dataEnable) begin
                $display("[%0t] dataEnable bật LẦN ĐẦU / sau idle, frame=%0d, RGB=%h",
                         $time, frame_count, RGBchannel);
            end
        end
    end

    // ----------------------------------------------------------------
    // Có thể theo dõi thêm fifo_read_en để xem lúc nào DUT bắt đầu đọc FIFO
    // ----------------------------------------------------------------
    reg fifo_read_en_d;

    always @(posedge clock or negedge resetn) begin
        if (!resetn) begin
            fifo_read_en_d <= 1'b0;
        end else begin
            fifo_read_en_d <= fifo_read_en;

            if (!fifo_read_en_d && fifo_read_en) begin
                $display("[%0t] fifo_read_en bật lần đầu, frame=%0d", 
                         $time, frame_count);
            end
        end
    end

endmodule

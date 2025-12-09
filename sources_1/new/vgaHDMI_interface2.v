`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/19/2025 04:51:10 PM
// Design Name: 
// Module Name: vgaHDMI_interface2
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

//////////////////////////////////////////////////////////////////////////////////
// **Info Source**
// https://eewiki.net/pages/viewpage.action?pageId=15925278
//
// VGA Timings 640x480 @ 60Hz (25.175MHz clock, chúng ta dùng 25MHz)
// ----------------------------------------------------------------
// Ngang (Horizontal) - Đơn vị: Pixels
// Visible Area:      640
// Front Porch:       16
// Sync Pulse:        96
// Back Porch:        48
// Total:             800
// 
// Dọc (Vertical) - Đơn vị: Lines
// Visible Area:      480
// Front Porch:       10
// Sync Pulse:        2
// Back Porch:        33
// Total:             525

module vgaHDMI_interface2(
    // **Inputs**
    input clock,        // 25MHz Pixel Clock
    input clock50,      // Clock 50MHz (dùng cho vgaClock như module gốc)
    input resetn,       // Tín hiệu Reset (Active-Low)
    
    // **FIFO Interface Inputs**
    input wire [15:0] fifo_data_in, // Dữ liệu RGB 16-bit (RGB565) từ FIFO
    input wire        fifo_empty,   // Cờ báo FIFO rỗng

    // **Outputs**
    output reg hsync,        // Horizontal Sync
    output reg vsync,        // Vertical Sync
    output reg dataEnable,   // (DE) Báo hiệu vùng pixel hợp lệ (ĐÃ TRỄ 1 CYCLE)
    output reg vgaClock,     // Clock cho ADV7511/HDMI (như module gốc)
    output wire [23:0] RGBchannel, // Dữ liệu RGB 24-bit (ĐÃ TRỄ 1 CYCLE)
    
    // **FIFO Interface Output**
    output reg fifo_read_en  // Yêu cầu FIFO đọc (Read Enable)
);

// Tín hiệu reset nội bộ, active-high
wire reset = !resetn;

// Bộ đếm pixel ngang và dọc
reg [9:0] pixelH; // Đếm từ 0-799
reg [9:0] pixelV; // Đếm từ 0-524

// Dây nội bộ để chứa dữ liệu 24-bit đã chuyển đổi (Tổ hợp)
wire [23:0] rgb888_data;

// Dây nội bộ cho tín hiệu data enable (trước khi trễ)
wire de_internal;

// --- Pipeline Registers (Trễ 1 chu kỳ để khớp với FIFO) ---
reg        dataEnable_d1;       // Tín hiệu Data Enable đã trễ 1 chu kỳ
reg [23:0] rgb_data_d1;         // Dữ liệu RGB đã trễ 1 chu kỳ (option)
reg        fifo_empty_d1;       // Tín hiệu Fifo Empty đã trễ 1 chu kỳ
// --- Hết Pipeline Registers ---

// NEW: cờ trạng thái
reg streaming;       // Đang phát video từ FIFO cho frame hiện tại
reg pending_start;   // Đã có data trong FIFO, chờ tới đầu frame mới để bắt đầu streaming

// NEW: các wire hỗ trợ
wire frame_start;   // đầu frame: pixelH == 0 && pixelV == 0
wire video_on;      // vùng hiển thị 640x480

assign frame_start = (pixelH == 10'd0) && (pixelV == 10'd0);
assign video_on    = (pixelH < 10'd640) && (pixelV < 10'd480);

// =================================================================
// 1. Bộ đếm Pixel (Horizontal & Vertical Counters)
// =================================================================
always @(posedge clock or posedge reset) begin
    if(reset) begin
        pixelH <= 10'd0;
        pixelV <= 10'd0;
    end
    else begin
        if(pixelH == 10'd799) begin
            pixelH <= 10'd0;
            
            if(pixelV == 10'd524) begin
                pixelV <= 10'd0; // Bắt đầu khung hình (frame) mới
            end
            else begin
                pixelV <= pixelV + 1'b1;
            end
        end
        else begin
            pixelH <= pixelH + 1'b1;
        end
    end
end

// =================================================================
// 1.b Điều khiển "streaming" và "pending_start"
// =================================================================
// Mục tiêu:
// - Khi FIFO lần đầu có data (fifo_empty từ 1 -> 0), KHÔNG stream ngay.
//   -> Đặt pending_start = 1 (đang chờ).
// - Tại frame_start (pixelH=0, pixelV=0):
//     + Nếu pending_start = 1 và FIFO vẫn còn data -> streaming = 1, bắt đầu stream.
// - Nếu đang streaming mà FIFO bị rỗng -> dừng streaming (frame sau mới phát tiếp).
always @(posedge clock or posedge reset) begin
    if (reset) begin
        streaming     <= 1'b0;
        pending_start <= 1'b0;
    end else begin
        // Nếu chưa streaming: theo dõi FIFO
        if (!streaming) begin
            // Lần đầu thấy FIFO có data -> nhớ lại, chờ tới đầu frame
            if (!fifo_empty)
                pending_start <= 1'b1;

            // Đến đầu frame: nếu có pending_start và FIFO vẫn có data -> bắt đầu stream
            if (frame_start && pending_start && !fifo_empty) begin
                streaming     <= 1'b1;
                pending_start <= 1'b0;
            end
        end
        // Nếu đang streaming
        else begin
            // FIFO cạn giữa chừng -> dừng stream.
            // Lúc này frame này sẽ phần còn lại bị đen,
            // và khi FIFO đầy lại thì quy trình "pending_start" sẽ bắt đầu lại cho frame tiếp theo.
            if (fifo_empty) begin
                streaming     <= 1'b0;
                pending_start <= 1'b0;
            end
        end
    end
end

// Tín hiệu Data Enable nội bộ (de_internal) - Không trễ
// Bây giờ chỉ phụ thuộc vào vùng hiển thị + đang streaming.
// Không gate trực tiếp với fifo_empty để tránh bật/tắt lặt vặt giữa frame.
assign de_internal = video_on && streaming; 

// =================================================================
// 2. Tạo tín hiệu Sync (hsync, vsync) và Data Enable (DE)
// =================================================================
always @(posedge clock or posedge reset) begin
    if(reset) begin
        hsync        <= 1'b1;
        vsync        <= 1'b1;
        dataEnable   <= 1'b0;
        fifo_read_en <= 1'b0;
        
        dataEnable_d1 <= 1'b0;
        rgb_data_d1   <= 24'h0;
        fifo_empty_d1 <= 1'b1;
    end
    else begin
        // --- Tín hiệu Ngang (Horizontal) ---
        if(pixelH >= 10'd656 && pixelH <= 10'd751)
            hsync <= 1'b0;
        else
            hsync <= 1'b1;

        // --- Tín hiệu Dọc (Vertical) ---
        if(pixelV >= 10'd490 && pixelV <= 10'd491)
            vsync <= 1'b0;
        else
            vsync <= 1'b1;

        // --- FIFO Read & Pipeline ---
        // Yêu cầu đọc FIFO khi đang ở vùng hiển thị và streaming.
        // Có thể thêm !fifo_empty để tránh underflow nếu FIFO không tự bảo vệ.
        fifo_read_en <= de_internal && !fifo_empty;

        fifo_empty_d1 <= fifo_empty;
        dataEnable_d1 <= de_internal;
        rgb_data_d1   <= rgb888_data; // nếu muốn dùng pipeline data

        // dataEnable xuất ra trễ 1 chu kỳ so với de_internal
        dataEnable <= dataEnable_d1;
    end
end

// =================================================================
// 3. Chuyển đổi RGB565 (16-bit) sang RGB888 (24-bit)
// =================================================================
assign rgb888_data[23:16] = { fifo_data_in[15:11], fifo_data_in[15:13] }; // Red
assign rgb888_data[15:8]  = { fifo_data_in[10:5],  fifo_data_in[10:9]  }; // Green
assign rgb888_data[7:0]   = { fifo_data_in[4:0],   fifo_data_in[4:2]   }; // Blue

// =================================================================
// 4. Xuất dữ liệu RGB từ FIFO (đã chuyển đổi VÀ ĐÃ TRỄ)
// =================================================================
// Nếu muốn dùng data pipeline chuẩn chỉnh thì dùng rgb_data_d1 thay vì rgb888_data.
// Ở đây mình vẫn gate bằng dataEnable_d1 + fifo_empty_d1 để tránh rác khi FIFO rỗng.
assign RGBchannel = (dataEnable_d1 && !fifo_empty_d1) ? rgb_data_d1 : 24'h000000;

// =================================================================
// 5. VGA Pixel Clock (Logic từ module gốc)
// =================================================================
always @(posedge clock50 or posedge reset) begin
    if(reset) 
        vgaClock <= 1'b0;
    else 
        vgaClock <= ~vgaClock;
end

endmodule


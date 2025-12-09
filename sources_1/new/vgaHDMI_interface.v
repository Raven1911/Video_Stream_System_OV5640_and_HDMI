`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/12/2025 10:17:06 PM
// Design Name: 
// Module Name: vgaHDMI_interface
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

module vgaHDMI_interface(
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
reg dataEnable_d1;       // Tín hiệu Data Enable đã trễ 1 chu kỳ
reg [23:0] rgb_data_d1;  // Dữ liệu RGB đã trễ 1 chu kỳ
reg fifo_empty_d1;       // Tín hiệu Fifo Empty đã trễ 1 chu kỳ
// --- Hết Pipeline Registers ---


// =================================================================
// 1. Bộ đếm Pixel (Horizontal & Vertical Counters)
//    Logic này đã được sửa lại cho chính xác.
// =================================================================
always @(posedge clock or posedge reset) begin
    if(reset) begin
        pixelH <= 10'd0;
        pixelV <= 10'd0;
    end
    else begin
        // Bộ đếm ngang (pixelH) đếm từ 0 đến 799
        if(pixelH == 10'd799) begin
            pixelH <= 10'd0;
            
            // Bộ đếm dọc (pixelV) chỉ tăng khi bộ đếm ngang (pixelH)
            // hoàn thành một dòng (tại 799)
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

// Tín hiệu Data Enable nội bộ (de_internal) - Không trễ
// Tín hiệu này sẽ được dùng để *yêu cầu* đọc FIFO
assign de_internal = ((pixelH <= 10'd640) && (pixelV <= 10'd480)) && (!fifo_empty); 

// =================================================================
// 2. Tạo tín hiệu Sync (hsync, vsync) và Data Enable (DE)
//    Đã sửa đổi để thêm pipeline 1-cycle cho data/DE
// =================================================================
always @(posedge clock or posedge reset) begin
    if(reset) begin
        hsync        <= 1'b1;
        vsync        <= 1'b1;
        dataEnable   <= 1'b0; // Tín hiệu DE ra bên ngoài (đã trễ)
        fifo_read_en <= 1'b0; // Tín hiệu yêu cầu đọc (không trễ)
        
        // Reset các thanh ghi pipeline
        dataEnable_d1 <= 1'b0;
        rgb_data_d1   <= 24'h0;
        fifo_empty_d1 <= 1'b1; // Giả sử rỗng khi reset
    end
    else begin
        // --- Tín hiệu Ngang (Horizontal) ---
        
        // Vùng hiển thị (Active Display): 0-639 (640 pixels)
        // H-Front Porch: 640-655 (16 pixels)
        // H-Sync Pulse:  656-751 (96 pixels) -> active low
        // H-Back Porch:  752-799 (48 pixels)
        
        // HSync (Active Low)
        if(pixelH >= 10'd656 && pixelH <= 10'd751)
            hsync <= 1'b0;
        else
            hsync <= 1'b1;

        // --- Tín hiệu Dọc (Vertical) ---
        
        // Vùng hiển thị (Active Display): 0-479 (480 lines)
        // V-Front Porch: 480-489 (10 lines)
        // V-Sync Pulse:  490-491 (2 lines) -> active low
        // V-Back Porch:  492-524 (33 lines)
        
        // VSync (Active Low)
        if(pixelV >= 10'd490 && pixelV <= 10'd491)
            vsync <= 1'b0;
        else
            vsync <= 1'b1;

        // --- Data Enable (DE) và FIFO Read Enable (Đã có Pipeline) ---
        
        // 1. Tín hiệu YÊU CẦU ĐỌC FIFO (fifo_read_en)
        //    Bật lên dựa trên vị trí hiện tại (không trễ).
        //    Tín hiệu này yêu cầu dữ liệu cho chu kỳ *tiếp theo*.
        fifo_read_en <= de_internal;

        // 2. Pipeline Dữ liệu và Tín hiệu DE
        //    Lưu trữ (chụp) các tín hiệu sẽ được sử dụng trong CHU KỲ TIẾP THEO.
        
        // Chụp (sample) dữ liệu từ FIFO (đã qua chuyển đổi)
        // `rgb888_data` là tổ hợp, nó lấy `fifo_data_in` hiện tại
        // rgb_data_d1 <= rgb888_data; 
        
        // Chụp (sample) cờ `empty` của FIFO
        fifo_empty_d1 <= fifo_empty;
        
        // Chụp (sample) tín hiệu DE nội bộ
        // (Tín hiệu này sẽ trở thành `dataEnable` ở đầu ra vào chu kỳ sau)
        dataEnable_d1 <= de_internal;

        // 3. Gán tín hiệu ĐẦU RA `dataEnable` (đã trễ 1 chu kỳ)
        //    Sử dụng các giá trị đã được đăng ký (registered) từ chu kỳ TRƯỚC.
        // dataEnable <= dataEnable_d1;
        dataEnable <= ((pixelH <= 10'd640) && (pixelV <= 10'd480)) && fifo_read_en;
    end
end

// =================================================================
// 3. Chuyển đổi RGB565 (16-bit) sang RGB888 (24-bit)
// =================================================================

// Định dạng RGB565: { R[4:0], G[5:0], B[4:0] }
// fifo_data_in[15:11] = Red (5 bits)
// fifo_data_in[10:5]  = Green (6 bits)
// fifo_data_in[4:0]   = Blue (5 bits)

// Chuyển đổi sang 24-bit (8-8-8)
// Red (8-bit)   = { R[4:0], R[4:2] }
// Green (8-bit) = { G[5:0], G[5:4] }
// Blue (8-bit)  = { B[4:0], B[4:2] }

assign rgb888_data[23:16] = { fifo_data_in[15:11], fifo_data_in[15:13] }; // Red
assign rgb888_data[15:8]  = { fifo_data_in[10:5],  fifo_data_in[10:9]  }; // Green
assign rgb888_data[7:0]   = { fifo_data_in[4:0],   fifo_data_in[4:2]   }; // Blue


// =================================================================
// 4. Xuất dữ liệu RGB từ FIFO (đã chuyển đổi VÀ ĐÃ TRỄ)
// =================================================================

// Gán tín hiệu RGB:
// - Sử dụng `dataEnable_d1` (tín hiệu DE đã trễ).
// - Sử dụng `fifo_empty_d1` (tín hiệu empty đã trễ, để khớp với dữ liệu).
// - Sử dụng `rgb_data_d1` (dữ liệu đã trễ).
//
// Nếu `dataEnable_d1` là 1 (chúng ta *nên* hiển thị) VÀ `fifo_empty_d1` là 0
// (dữ liệu đi kèm hợp lệ), thì xuất `rgb_data_d1`.
// Ngược lại (đang ở blanking HOẶC FIFO bị rỗng), xuất màu đen.
assign RGBchannel = (dataEnable_d1 && !fifo_empty_d1) ? rgb888_data : 24'h000000;


// =================================================================
// 5. VGA Pixel Clock (Logic từ module gốc)
// =================================================================
// Tác giả gốc dùng clock50 để tạo vgaClock. 
// Giả sử 'clock' (25MHz) đã được tạo ra bởi một PLL
// và 'vgaClock' này được dùng cho chip HDMI.
// Chúng ta giữ nguyên logic này.
always @(posedge clock50 or posedge reset) begin // Sử dụng tín hiệu 'reset' (active-high) nội bộ
    if(reset) 
        vgaClock <= 1'b0;
    else 
        vgaClock <= ~vgaClock;
end

endmodule


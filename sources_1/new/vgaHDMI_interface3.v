`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/25/2025 04:03:15 PM
// Design Name: 
// Module Name: vgaHDMI_interface3
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


// module vgaHDMI_interface3(
//     // **input**
//     input clock25, clock50, resetn,

//     input wire              empty_fifo, // FIFO empty flag
//     input wire [15:0]       fifo_data_in, // RGB565 data from FIFO
//     output reg              fifo_read_en, // FIFO read enable

//     // **output**
//     output  hsync, vsync,
//     output  dataEnable,
//     output  vgaClock,
//     output /* reg */ [23:0] RGBchannel
//     );

//     //FSM state declarations
// 	localparam      DELAY = 0,
// 					IDLE = 1,
// 					DISPLAY = 2;

//     reg[1:0]    state_q,state_d;
//     reg [23:0]  RGBchannel_q, RGBchannel_d;
// 	wire[9:0]   pixel_x,pixel_y;

//     //register operations
//     always @(posedge clock25, negedge resetn) begin
//         if(!resetn) begin
//             state_q<=DELAY;
//             RGBchannel_q <= 24'b0;
//         end
//         else begin
//             state_q<=state_d;
//             RGBchannel_q <= RGBchannel_d;
//         end
//     end


//     //FSM next-state logic
//         always @* begin
//         state_d=state_q; 
//         RGBchannel_d = RGBchannel_q;
//         fifo_read_en=0;
//         // RGBchannel=24'b0;
//         case(state_q)
//             DELAY: if(pixel_x==1 && pixel_y==1) state_d=IDLE; //delay of one frame(33ms) needed to start up the camera
//             IDLE:  if(pixel_x==1 && pixel_y==0 && !empty_fifo) begin //wait for pixel-data coming from asyn_fifo 
//                             RGBchannel_d = {fifo_data_in[15:11],3'b000, fifo_data_in[10:5],2'b00, fifo_data_in[4:0],3'b000}; //convert RGB565 to RGB888
//                             // RGBchannel_d = 24'hF8FCF8;
//                             fifo_read_en = 1;	
//                             state_d = DISPLAY;
//                     end
//             DISPLAY: if(pixel_x>=1 && pixel_x<=640 && pixel_y<480) begin //we will continue to read the asyn_fifo as long as current pixel coordinate is inside the visible screen(640x480) 
//                             // RGBchannel_d = {fifo_data_in[15:11],3'b000, fifo_data_in[10:5],2'b00, fifo_data_in[4:0],3'b000}; //convert RGB565 to RGB888
//                             //RGBchannel_d = 24'hF8FCF8;
//                             fifo_read_en = 1;	

//                             if (empty_fifo) begin
//                                 // TRƯỜNG HỢP 1: FIFO RỖNG -> Xuất màu ĐỎ để báo lỗi
//                                 RGBchannel_d = 24'hFF0000; 
//                             end 
//                             // else if (fifo_data_in == 16'h0000) begin
//                             //     // TRƯỜNG HỢP 2: FIFO CÓ DATA NHƯNG LÀ 0 -> Xuất màu XANH DƯƠNG
//                             //     // (Có thể do camera đang bị che tối om)
//                             //     RGBchannel_d = 24'h0000FF;
//                             // end 
//                             else begin
//                                 // TRƯỜNG HỢP 3: CHẠY THẬT
//                                 RGBchannel_d = {fifo_data_in[15:11], 3'b000, fifo_data_in[10:5], 2'b00, fifo_data_in[4:0], 3'b000};
//                             end
//                         end
//             // default: state_d=DELAY;
//             IDLE: state_d=DELAY;
//         endcase
//         end

//     assign RGBchannel = RGBchannel_q;

//     //module instantiations
// 	vgaHDMI_core m0
// 	(
// 		.clock25(clock25), //clock must be 25MHz for 640x480
//         .clock50(clock50),
// 		.resetn(resetn),  
// 		.hsync(hsync),
// 		.vsync(vsync),
// 		.dataEnable(dataEnable),
//         .vgaClock(vgaClock),
// 		.pixel_x(pixel_x),
// 		.pixel_y(pixel_y)
// 	);



// endmodule


module vgaHDMI_interface3(
    // **input**
    input clock25, clock50, resetn,

    input wire              empty_fifo,    
    input wire [15:0]       fifo_data_in,  
    output wire             fifo_read_en, // Output dạng WIRE

    // **output**
    output reg              hsync, vsync,
    output reg              dataEnable,
    output                  vgaClock,
    output reg [23:0]       RGBchannel
    );

    // Tín hiệu từ Core
    wire hsync_raw, vsync_raw, de_raw;
    wire [9:0] pixel_x, pixel_y;

    // -----------------------------------------------------------
    // KỸ THUẬT PRE-FETCH (ĐỌC TRƯỚC)
    // Thay vì đợi 'de_raw' lên 1 mới đọc, ta đọc khi 'de_raw' chuẩn bị lên 1.
    // Tuy nhiên, để đơn giản và hiệu quả với hệ thống của bạn:
    // Ta vẫn đọc bằng 'de_raw', NHƯNG ta sẽ KHÔNG làm trễ HSYNC/VSYNC nữa.
    // Thay vào đó, ta chấp nhận mất pixel đầu tiên (cực nhỏ) để đổi lấy sự đồng bộ.
    // -----------------------------------------------------------

    // Logic đọc: Đọc liên tục khi đang ở vùng hiển thị
    assign fifo_read_en = de_raw && !empty_fifo;

    always @(posedge clock25 or negedge resetn) begin
        if(!resetn) begin
            hsync       <= 1;
            vsync       <= 1;
            dataEnable  <= 0;
            RGBchannel  <= 0;
        end
        else begin
            // 1. Đồng bộ tín hiệu Sync (Giữ nguyên, không làm trễ thêm)
            hsync       <= hsync_raw;
            vsync       <= vsync_raw;
            dataEnable  <= de_raw;

            // 2. Xử lý dữ liệu
            // Ở chu kỳ T: fifo_read_en = 1.
            // Ở chu kỳ T+1: fifo_data_in có dữ liệu mới.
            // Vì vậy, pixel hiển thị sẽ bị lệch 1 nhịp.
            // Để mắt không thấy nhoè, ta buộc phải gán ĐEN nếu không có data hợp lệ.
            
            if (de_raw && !empty_fifo) begin
                 // Map dữ liệu: 
                 // Do độ trễ 1 nhịp của FIFO, pixel tại vị trí X sẽ hiển thị dữ liệu của X-1.
                 // Với độ phân giải 640x480, lệch 1 pixel sang phải là chấp nhận được
                 // miễn là không bị nhoè.
                 RGBchannel <= {fifo_data_in[15:11], 3'b000, fifo_data_in[10:5], 2'b00, fifo_data_in[4:0], 3'b000};
            end
            else begin
                 // QUAN TRỌNG: Nếu không trong vùng hiển thị HOẶC FIFO rỗng
                 // Phải gán màu ĐEN tuyệt đối để tránh vệt nhoè/bóng ma.
                 RGBchannel <= 24'h000000;
            end
        end
    end

    // Instantiate Core
    vgaHDMI_core m0 (
        .clock25(clock25), 
        .clock50(clock50),
        .resetn(resetn),  
        .hsync(hsync_raw),
        .vsync(vsync_raw),
        .dataEnable(de_raw),
        .vgaClock(vgaClock),
        .pixel_x(pixel_x),
        .pixel_y(pixel_y)
    );

endmodule


module vgaHDMI_core(
    // **input**
    input clock25, clock50, resetn,

    // **output**
    output [9:0] pixel_x, pixel_y,
    output reg hsync, vsync,
    output reg dataEnable,
    output reg vgaClock
    );



    reg [9:0]pixelH, pixelV; // estado interno de pixeles del modulo

    initial begin
        hsync      = 1;
        vsync      = 1;
        pixelH     = 0;
        pixelV     = 0;
        dataEnable = 0;
        vgaClock   = 0;
    end
    
    // Manejo de Pixeles y Sincronizacion

    always @(posedge clock25 or negedge resetn) begin
    if(~resetn) begin
        hsync  <= 1;
        vsync  <= 1;
        pixelH <= 0;
        pixelV <= 0;
    end
    else begin
        // Display Horizontal
        if(pixelH==0 && pixelV!=524) begin
        pixelH<=pixelH+1'b1;
        pixelV<=pixelV+1'b1;
        end
        else if(pixelH==0 && pixelV==524) begin
        pixelH <= pixelH + 1'b1;
        pixelV <= 0; // pixel 525
        end
        else if(pixelH<=640) pixelH <= pixelH + 1'b1;
        // Front Porch
        else if(pixelH<=656) pixelH <= pixelH + 1'b1;
        // Sync Pulse
        else if(pixelH<=752) begin
        pixelH <= pixelH + 1'b1;
        hsync  <= 0;
        end
        // Back Porch
        else if(pixelH<799) begin
        pixelH <= pixelH+1'b1;
        hsync  <= 1;
        end
        else pixelH<=0; // pixel 800

        // Manejo Senal Vertical
        // Sync Pulse
        if(pixelV == 491 || pixelV == 492)
        vsync <= 0;
        else
        vsync <= 1;
    end
    end

    
    // dataEnable signal
    always @(posedge clock25 or negedge resetn) begin
    if(~resetn) dataEnable<= 0;

    else begin
        if(pixelH >= 0 && pixelH <640 && pixelV >= 0 && pixelV < 480)
        dataEnable <= 1;
        else
        dataEnable <= 0;
    end
    end

    // VGA pixeClock signal
    // Los clocks no deben manejar salidas directas, se debe usar un truco
    // initial vgaClock = 0;

    always @(posedge clock50 or negedge resetn) begin
    if(~resetn) vgaClock <= 0;
    else        vgaClock <= ~vgaClock;
    end


    assign pixel_x = pixelH;
    assign pixel_y = pixelV;


endmodule



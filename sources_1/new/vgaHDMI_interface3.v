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


module vgaHDMI_interface3(
    // **input**
    input clock25, clock50, resetn,

    input wire              empty_fifo, // FIFO empty flag
    input wire [15:0]       fifo_data_in, // RGB565 data from FIFO
    output reg              fifo_read_en, // FIFO read enable

    // **output**
    output  hsync, vsync,
    output  dataEnable,
    output  vgaClock,
    output /* reg */ [23:0] RGBchannel
    );

    //FSM state declarations
	localparam      DELAY = 0,
					IDLE = 1,
					DISPLAY = 2;

    reg[1:0]    state_q,state_d;
    reg [23:0]  RGBchannel_q, RGBchannel_d;
	wire[9:0]   pixel_x,pixel_y;

    //register operations
    always @(posedge clock25, negedge resetn) begin
        if(!resetn) begin
            state_q<=DELAY;
            RGBchannel_q <= 24'b0;
        end
        else begin
            state_q<=state_d;
            RGBchannel_q <= RGBchannel_d;
        end
    end


    //FSM next-state logic
        always @* begin
        state_d=state_q; 
        RGBchannel_d = RGBchannel_q;
        fifo_read_en=0;
        // RGBchannel=24'b0;
        case(state_q)
            DELAY: if(pixel_x==1 && pixel_y==1) state_d=IDLE; //delay of one frame(33ms) needed to start up the camera
            IDLE:  if(pixel_x==1 && pixel_y==0 && !empty_fifo) begin //wait for pixel-data coming from asyn_fifo 
                            RGBchannel_d = {fifo_data_in[15:11],3'b000, fifo_data_in[10:5],2'b00, fifo_data_in[4:0],3'b000}; //convert RGB565 to RGB888
                            // RGBchannel_d = 24'hF8FCF8;
                            fifo_read_en = 1;	
                            state_d = DISPLAY;
                    end
            DISPLAY: if(pixel_x>=1 && pixel_x<=640 && pixel_y<480) begin //we will continue to read the asyn_fifo as long as current pixel coordinate is inside the visible screen(640x480) 
                            // RGBchannel_d = {fifo_data_in[15:11],3'b000, fifo_data_in[10:5],2'b00, fifo_data_in[4:0],3'b000}; //convert RGB565 to RGB888
                            //RGBchannel_d = 24'hF8FCF8;
                            fifo_read_en = 1;	

                            if (empty_fifo) begin
                                // TRƯỜNG HỢP 1: FIFO RỖNG -> Xuất màu ĐỎ để báo lỗi
                                RGBchannel_d = 24'hFF0000; 
                            end 
                            // else if (fifo_data_in == 16'h0000) begin
                            //     // TRƯỜNG HỢP 2: FIFO CÓ DATA NHƯNG LÀ 0 -> Xuất màu XANH DƯƠNG
                            //     // (Có thể do camera đang bị che tối om)
                            //     RGBchannel_d = 24'h0000FF;
                            // end 
                            else begin
                                // TRƯỜNG HỢP 3: CHẠY THẬT
                                RGBchannel_d = {fifo_data_in[15:11], 3'b000, fifo_data_in[10:5], 2'b00, fifo_data_in[4:0], 3'b000};
                            end
                        end
            // default: state_d=DELAY;
            IDLE: state_d=DELAY;
        endcase
        end

    assign RGBchannel = RGBchannel_q;

    //module instantiations
	vgaHDMI_core m0
	(
		.clock25(clock25), //clock must be 25MHz for 640x480
        .clock50(clock50),
		.resetn(resetn),  
		.hsync(hsync),
		.vsync(vsync),
		.dataEnable(dataEnable),
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



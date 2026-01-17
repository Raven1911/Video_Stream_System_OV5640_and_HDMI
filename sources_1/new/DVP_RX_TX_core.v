`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/26/2025 02:24:24 PM
// Design Name: 
// Module Name: DVP_RX_TX_core
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
module DVP_RX_TX_core#(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH_FIFO = 11,
    parameter DATA_WIDTH_FIFO = 16,

    parameter BRAM_ADDR_WIDTH = 32,
    parameter BRAM_DATA_WIDTH = 16,
    parameter BRAM_NUMBER_BLOCK = 75,
    parameter BRAM_DEPTH_SIZE = 4096,
    parameter BRAM_MODE = 2,
    parameter BRAM_ENB_TEST_PATTERN = 0,

    parameter FIFO_DATA_WIDTH = 16,
    parameter FIFO_DEPTH_WIDTH = 9



)(
    // System Clock Domain
    input                           clk_i,      // System clock (Faster than cam_pclk_i)
    input                           clk25MHz_i, // clock ip hdmi
    input                           clk50MHz_i, // clock ip hdmi
    input                           resetn_i,   // Asynchronous reset (active low)

    // Camera Interface (Asynchronous to clk_i)
    input                           cam_pclk_i,
    input   [DATA_WIDTH-1:0]        cam_half_pixel_i, // Incoming 8-bit pixel data
    input                           cam_href,   // Horizontal Enable
    input                           cam_vsync,  // Vertical Sync


    output                          hsync,        // Horizontal Sync
    output                          vsync,        // Vertical Sync
    output                          dataEnable,   // (DE) Báo hiệu vùng pixel hợp lệ (ĐÃ TRỄ 1 CYCLE)
    output                          vgaClock,     // Clock cho ADV7511/HDMI (như module gốc)
    output  [23:0]                  RGBchannel, // Dữ liệu RGB 24-bit (ĐÃ TRỄ 1 CYCLE)

    //config frame
    input   [15:0]                  resolution_width_i,
    input   [15:0]                  resolution_depth_i




    );


    wire                            wr_pixel_o;
    wire    [DATA_WIDTH*2-1:0]      pixel_data_o;



    // Instantiate the Unit Under Test (DUT)

    // pixel_data_capture #(
    //     .DATA_WIDTH (DATA_WIDTH)
    // ) camera_interface (
    //     .clk_i              (clk_i),
    //     .resetn_i           (resetn_i),
    //     .cam_pclk_i         (cam_pclk_i),
    //     .cam_half_pixel_i   (cam_half_pixel_i),
    //     .cam_href           (cam_href),
    //     .cam_vsync          (cam_vsync),

    //     .wr_pixel_o         (wr_pixel_o),
    //     .pixel_data_o       (pixel_data_o)
    // );

    ov5640_data ov5640_data_inst(

        .sys_rst_n          (resetn_i),  //复位信号
        .ov5640_pclk        (cam_pclk_i    ),   //摄像头像素时钟
        .ov5640_href        (cam_href    ),   //摄像头行同步信号
        .ov5640_vsync       (cam_vsync   ),   //摄像头场同步信号
        .ov5640_data        (cam_half_pixel_i    ),   //摄像头图像数据

        .ov5640_wr_en       (wr_pixel_o   ),   //图像数据有效使能信号
        .ov5640_data_out    (pixel_data_o)    //图像数据

    );


    wire [FIFO_DEPTH_WIDTH-1:0] data_count_r;

    asyn_fifo #(.DATA_WIDTH(FIFO_DATA_WIDTH),.FIFO_DEPTH_WIDTH(FIFO_DEPTH_WIDTH)
    ) fifo_camera(
		.rst_n(resetn_i),
		.clk_write(cam_pclk_i),
		.clk_read(clk_i), //clock input from both domains
		.write(wr_pixel_o),
		.read(ctrl_wr), 
		.data_write(pixel_data_o), //input FROM write clock domain
		.data_read(ctrl_data_i), //output TO read clock domain
		//.full(),
		.empty(ctrl_empty), //full=sync to write domain clk , empty=sync to read domain clk
        //.data_count_w(),
		.data_count_r(data_count_r)
    );

    // fifo_dvp_unit#(
    //     .ADDR_WIDTH(ADDR_WIDTH_FIFO),
    //     .DATA_WIDTH(DATA_WIDTH_FIFO)
    // ) fifo_camera (
    //     .clk(clk_i), 
    //     .reset_n(resetn_i),
    //     .wr(wr_pixel_o), 
    //     .rd(ctrl_wr),

    //     .w_data(pixel_data_o), //writing data
    //     .r_data(ctrl_data_i), //reading data

    //     .full(), 
    //     .empty(ctrl_empty)
    // );


    frame_buffer # (
        .ADDR_WIDTH     (BRAM_ADDR_WIDTH),
        .DATA_WIDTH     (BRAM_DATA_WIDTH),
        .NUMBER_BRAM    (BRAM_NUMBER_BLOCK),
        .DEPTH_SIZE     (BRAM_DEPTH_SIZE),
        .MODE           (BRAM_MODE),
        .ENB_TEST_PATTERN(BRAM_ENB_TEST_PATTERN)
    ) frame_buffer_unit (
        .clk_i    (clk_i),
        .resetn_i (resetn_i),

        .wr0_i    (ctrl_wr),
        //.wr1_i    (),

        .addr_wr0 (ctrl_addr_wr),
        //.addr_wr1 (),
        .addr_rd0 (ctrl_addr_rd),
        //.addr_rd1 (),

        .Data_in0 (ctrl_data_i),
        //.Data_in1 (),
        .Data_out0(ctrl_data_o)//,
        //.Data_out1()
    );

    wire ctrl_empty;
    wire ctrl_full;
    wire ctrl_wr;
    wire ctrl_rd;
    wire ctrl2fifo_rd;

    wire [BRAM_ADDR_WIDTH-1:0]  ctrl_addr_wr;
    wire [BRAM_ADDR_WIDTH-1:0]  ctrl_addr_rd;

    wire [DATA_WIDTH*2-1:0]     ctrl_data_i;
    wire [DATA_WIDTH*2-1:0]     ctrl_data_o;


    wire page_written_once_wire;
    control_frame_buffer_write_only #(
        .ADDR_WIDTH(BRAM_ADDR_WIDTH),
        .FIFO_DEPTH_WIDTH(FIFO_DEPTH_WIDTH)
    ) control_write_frame_buffer (
        .clk_i(clk_i),
        .resetn_i(resetn_i),

        .resolution_width_i(resolution_width_i),
        .resolution_depth_i(resolution_depth_i),

        .empty_i(ctrl_empty),
        .data_count_r_i(data_count_r),

        .wr_o(ctrl_wr),
        .addr_wr_o(ctrl_addr_wr),
        .page_written_once_o(page_written_once_wire)
    );

    control_frame_buffer_read_only #(
        .ADDR_WIDTH(BRAM_ADDR_WIDTH),
        .READ_STROBE_PERIOD(1),
        .FIFO_DEPTH_WIDTH(FIFO_DEPTH_WIDTH)
    ) control_read_frame_buffer (
        .clk_i(clk_i),  
        .resetn_i(resetn_i),

        .resolution_width_i(resolution_width_i),
        .resolution_depth_i(resolution_depth_i),

        .page_written_once_i(page_written_once_wire),
        .full_i(ctrl_full),
        .data_count_w_i(data_count_w),

        .rd_o(ctrl_rd),
        .addr_rd_o(ctrl_addr_rd)
    );


    register_DFF #(
        .SIZE_BITS(1)
    ) register_DFF_HDMI_FIFO (
        .clk_i(clk_i),
        .resetn_i(resetn_i),
        .D_i(ctrl_rd),
        .Q_o(ctrl2fifo_rd)
    );

    // fifo_dvp_unit#(
    //     .ADDR_WIDTH(ADDR_WIDTH_FIFO),
    //     .DATA_WIDTH(DATA_WIDTH_FIFO)
    // ) fifo_hdmi (
    //     .clk(clk_i), 
    //     .reset_n(resetn_i),
    //     .wr(ctrl2fifo_rd), 
    //     .rd(0),

    //     .w_data(ctrl_data_o), //writing data
    //     .r_data(), //reading data

    //     .full(ctrl_full), 
    //     .empty()
    // );

    wire wr_fifo_hdmi;
    assign wr_fifo_hdmi = /* ctrl_rd | */ ctrl2fifo_rd;
    
    wire [FIFO_DEPTH_WIDTH-1:0] data_count_w;

    asyn_fifo #(.DATA_WIDTH(FIFO_DATA_WIDTH),.FIFO_DEPTH_WIDTH(FIFO_DEPTH_WIDTH)
    ) fifo_hdmi(
		.rst_n(resetn_i),
		.clk_write(clk_i),
		.clk_read(clk25MHz_i), //clock input from both domains
		.write(wr_fifo_hdmi),
		.read(fifo_read_en), 
		.data_write(ctrl_data_o), //input FROM write clock domain
		.data_read(rgb565_wire), //output TO read clock domain
		.full(ctrl_full),
		.empty(fifo_hdmi_empty), //full=sync to write domain clk , empty=sync to read domain clk
        .data_count_w(data_count_w)//,
		//.data_count_r() //asserted if fifo is equal or more than than half of its max capacity
    );


    // fifo_dvp_unit#(
    //     .ADDR_WIDTH(ADDR_WIDTH_FIFO),
    //     .DATA_WIDTH(DATA_WIDTH_FIFO)
    // ) fifo_hdmi (
    //     .clk(clk_i), 
    //     .reset_n(resetn_i),
    //     .wr(wr_fifo_hdmi), 
    //     .rd(fifo_read_en),

    //     .w_data(ctrl_data_o), //writing data
    //     .r_data(rgb565_wire), //reading data

    //     .full(ctrl_full), 
    //     .empty(fifo_hdmi_empty)
    // );

    wire    [15:0]      rgb565_wire;
    wire                fifo_read_en, fifo_hdmi_empty; 



    vgaHDMI_interface3 HDMI_interface_uut (
        .clock25(clk25MHz_i),
        .clock50(clk50MHz_i),
        .resetn(resetn_i),
        .fifo_data_in(rgb565_wire), 
        .empty_fifo(fifo_hdmi_empty),
        .hsync(hsync),
        .vsync(vsync),
        .dataEnable(dataEnable),
        .vgaClock(vgaClock),
        .RGBchannel(RGBchannel),
        .fifo_read_en(fifo_read_en)
    );

endmodule


module register_DFF#(
    SIZE_BITS = 32
)(  
    input                           clk_i,
    input                           resetn_i,
    input       [SIZE_BITS-1:0]    D_i,

    output  reg [SIZE_BITS-1:0]    Q_o
);
    always @(posedge clk_i, negedge resetn_i) begin
        if (~resetn_i) begin
            Q_o <= 0;
        end
        else begin
            Q_o <= D_i;
        end
    end

endmodule
































//FIFO

//module fifo
module fifo_dvp_unit #(parameter ADDR_WIDTH = 3, DATA_WIDTH = 8)(
    input clk, reset_n,
    input wr, rd,

    input [DATA_WIDTH - 1 : 0] w_data, //writing data
    output [DATA_WIDTH - 1 : 0] r_data, //reading data

    output full, empty

    );

    //signal
    wire [ADDR_WIDTH - 1 : 0] w_addr, r_addr;

    //instantiate registers file
    register_file_dvp #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH))
        reg_file_dvp_unit(
            .clk(clk),
            .w_en(~full & wr),

            .r_addr(r_addr), //reading address
            .w_addr(w_addr), //writing address

            .w_data(w_data), //writing data
            .r_data(r_data) //reading data
        
        );

    //instantiate fifo ctrl
    fifo_ctrl_dvp #(.ADDR_WIDTH(ADDR_WIDTH))
        fifo_ctrl_dvp_unit(
            .clk(clk), 
            .reset_n(reset_n),
            .wr(wr), 
            .rd(rd),

            .full(full),
            .empty(empty),

            .w_addr(w_addr),
            .r_addr(r_addr)
        );

endmodule


module fifo_ctrl_dvp #(parameter ADDR_WIDTH = 3)(
    input clk, reset_n,
    input wr, rd,

    output reg full, empty,

    output [ADDR_WIDTH - 1 : 0] w_addr,
    output [ADDR_WIDTH - 1 : 0] r_addr
    );

    //variable sequential
    reg [ADDR_WIDTH - 1 : 0] w_ptr, w_ptr_next;
    reg [ADDR_WIDTH - 1 : 0] r_ptr, r_ptr_next;
 
    reg full_next, empty_next;


    // sequential circuit
    always @(posedge clk, negedge reset_n) begin
        if(~reset_n)begin
            w_ptr <= 'b0;
            r_ptr <= 'b0;
            full <= 1'b0;
            empty <= 1'b1;
        end

        else begin
            w_ptr <= w_ptr_next;
            r_ptr <= r_ptr_next;
            full <= full_next;
            empty <= empty_next;
        end

    end

    //combi circuit
    always @(*)begin
        //default
        w_ptr_next = w_ptr;
        r_ptr_next = r_ptr;
        full_next = full;
        empty_next = empty;

        case ({wr, rd})
            2'b01: begin    //read
                if(~empty)begin
                    r_ptr_next = r_ptr + 1;
                    full_next = 1'b0;
                    if(r_ptr_next == w_ptr)begin
                        empty_next = 1'b1;
                    end
                end
            end

            2'b10: begin    //write
                if(~full)begin
                    w_ptr_next = w_ptr + 1;
                    empty_next = 1'b0;
                    if(w_ptr_next == r_ptr)begin
                        full_next = 1'b1;
                    end
                end
            end

            2'b11: begin    //read & write
                if(empty)begin
                    w_ptr_next = w_ptr;
                    r_ptr_next = r_ptr;
                end

                else begin
                    w_ptr_next = w_ptr + 1;
                    r_ptr_next = r_ptr + 1;
                end
            end

            default: ; // 2'b00
        endcase


    end

    //output
    assign w_addr = w_ptr;
    assign r_addr = r_ptr;

endmodule



module register_file_dvp #(parameter ADDR_WIDTH = 3, DATA_WIDTH = 8)(
    input clk,
    input w_en,

    input [ADDR_WIDTH - 1 : 0] r_addr, //reading address
    input [ADDR_WIDTH - 1 : 0] w_addr, //writing address

    input [DATA_WIDTH - 1 : 0] w_data, //writing data
    output [DATA_WIDTH - 1 : 0] r_data //reading data
    );

    //memory buffer
    reg [DATA_WIDTH -1 : 0] memory [0 : 2 ** ADDR_WIDTH - 1];

    //wire operation
    always @(posedge clk) begin
        if (w_en) memory[w_addr] <= w_data;
        
    end

    //read operation
    assign r_data = memory[r_addr];

endmodule
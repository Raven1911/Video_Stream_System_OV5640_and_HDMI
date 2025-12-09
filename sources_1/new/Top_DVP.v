`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/16/2025 03:57:09 PM
// Design Name: 
// Module Name: Top_DVP
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


module Top_DVP#(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH_FIFO = 11,
    parameter DATA_WIDTH_FIFO = 16,

    parameter BRAM_ADDR_WIDTH = 32,
    parameter BRAM_DATA_WIDTH = 16,
    parameter BRAM_NUMBER_BLOCK = 75, //75
    parameter BRAM_DEPTH_SIZE = 4096,
    parameter BRAM_MODE = 2

)(
    // System Clock Domain
    input                           clk_in_p,
    input                           clk_in_n,
    input                           resetn_i,   // Asynchronous reset (active low)

    // Camera Interface (Asynchronous to clk_i)
    input                           cam_pclk_i,
    input   [DATA_WIDTH-1:0]        cam_half_pixel_i, // Incoming 8-bit pixel data
    input                           cam_href,   // Horizontal Enable
    input                           cam_vsync,  // Vertical Sync


    output                          HDMI_TX_HS,        // Horizontal Sync
    output                          HDMI_TX_VS,        // Vertical Sync
    output                          HDMI_TX_DE,   // (DE) Báo hiệu vùng pixel hợp lệ (ĐÃ TRỄ 1 CYCLE)
    output                          HDMI_TX_CLK,     // Clock cho ADV7511/HDMI (như module gốc)
    output  [23:0]                  HDMI_TX_D // Dữ liệu RGB 24-bit (ĐÃ TRỄ 1 CYCLE)

    //config frame
    );



    wire clk_200MHz, clk_50MHz, clk_25MHz; 
    // wire locked;
    clk_wiz_0 genclk
    (
        // Clock out ports
        .clk_out200MHz(clk_200MHz),
        .clk_out50MHz(clk_50MHz),
        .clk_out25MHz(clk_25MHz),
        // Status and control signals
        .resetn(resetn_i),
        .locked(locked),
        // Clock in ports
        .clk_in1_p(clk_in_p),
        .clk_in1_n(clk_in_n)
    );


    DVP_RX_TX_core #(
        .DATA_WIDTH        (DATA_WIDTH),
        .ADDR_WIDTH_FIFO   (ADDR_WIDTH_FIFO),
        .DATA_WIDTH_FIFO   (DATA_WIDTH_FIFO),
        .BRAM_ADDR_WIDTH   (BRAM_ADDR_WIDTH),
        .BRAM_DATA_WIDTH   (BRAM_DATA_WIDTH),
        .BRAM_NUMBER_BLOCK (BRAM_NUMBER_BLOCK),
        .BRAM_DEPTH_SIZE   (BRAM_DEPTH_SIZE),
        .BRAM_MODE         (BRAM_MODE)
    )
    DVP_core (
        // System Clock Domain
        .clk_i               (clk_200MHz),
        .clk25MHz_i          (clk_25MHz),
        .clk50MHz_i          (clk_50MHz),
        .resetn_i            (locked/* resetn_i */),

        // Camera Interface
        .cam_pclk_i          (cam_pclk_i),
        .cam_half_pixel_i    (cam_half_pixel_i),
        .cam_href            (cam_href),
        .cam_vsync           (cam_vsync),

        // DUT Outputs
        .hsync               (HDMI_TX_HS),
        .vsync               (HDMI_TX_VS),
        .dataEnable          (HDMI_TX_DE),
        .vgaClock            (HDMI_TX_CLK),
        .RGBchannel          (HDMI_TX_D),

        // Config Frame
        .resolution_width_i  ('d640),
        .resolution_depth_i  ('d480)
    );



endmodule

`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/10/2026 09:59:49 PM
// Design Name: 
// Module Name: tb_uiSensorRGB565
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

module tb_uiSensorRGB565;

    //================================================================
    // 1. PARAMETERS & SIGNALS
    //================================================================
    parameter TEST_WIDTH  = 640;
    parameter TEST_HEIGHT = 480;
    parameter FRAMES_TO_SIM = 7; 

    reg rstn_i;
    reg cmos_clk_i;
    reg cmos_pclk_i;
    reg cmos_href_i;
    reg cmos_vsync_i;
    reg [7:0] cmos_data_i;

    wire cmos_xclk_o;
    wire [15:0] rgb_o;
    wire de_o;
    wire vs_o;
    wire hs_o;

    //================================================================
    // 2. DUT INSTANTIATION
    //================================================================
    uiSensorRGB565 uut (
        .rstn_i(rstn_i),
        .cmos_clk_i(cmos_clk_i),
        .cmos_pclk_i(cmos_pclk_i),
        .cmos_href_i(cmos_href_i),
        .cmos_vsync_i(cmos_vsync_i),
        .cmos_data_i(cmos_data_i),
        .cmos_xclk_o(cmos_xclk_o),
        .rgb_o(rgb_o),
        .de_o(de_o),
        .vs_o(vs_o),
        .hs_o(hs_o)
    );

    //================================================================
    // 3. CLOCK GENERATION (50MHz PCLK)
    //================================================================
    initial begin
        cmos_clk_i  = 0;
        cmos_pclk_i = 0;
    end

    // XCLK (thường dùng cho CMOS sensor, giả sử 24MHz)
    always #20.833 cmos_clk_i = ~cmos_clk_i; 
    
    // PCLK = 50MHz -> T = 20ns -> Nửa chu kỳ = 10ns
    always #10 cmos_pclk_i = ~cmos_pclk_i;

    //================================================================
    // 4. MAIN SIMULATION SEQUENCE
    //================================================================
    initial begin
        // Khởi tạo
        rstn_i       = 0;
        cmos_href_i  = 0;
        cmos_vsync_i = 0;
        cmos_data_i  = 8'h00;

        #100;
        rstn_i = 1;
        #100;

        $display("--- BAT DAU MO PHONG: PCLK = 50MHz | Frames = %0d ---", FRAMES_TO_SIM);

        for (int f = 0; f < FRAMES_TO_SIM; f++) begin
            send_frame(f);
            repeat(100) @(posedge cmos_pclk_i);
        end

        $display("--- MO PHONG HOAN THANH ---");
        $finish;
    end

    // Task gửi 1 Frame DVP
    task send_frame(int frame_id);
        begin
            // VSYNC Active High
            cmos_vsync_i = 1;
            repeat(10) @(posedge cmos_pclk_i);
            cmos_vsync_i = 0;
            
            repeat(20) @(posedge cmos_pclk_i); // Vertical Back Porch

            for (int y = 0; y < TEST_HEIGHT; y++) begin
                @(posedge cmos_pclk_i);
                cmos_href_i = 1;

                for (int x = 0; x < TEST_WIDTH; x++) begin
                    // Pixel Byte 1
                    cmos_data_i = 8'hAA; 
                    @(posedge cmos_pclk_i);
                    
                    // Pixel Byte 2
                    cmos_data_i = 8'hBB; 
                    @(posedge cmos_pclk_i);
                end

                cmos_href_i = 0;
                cmos_data_i = 8'h00;
                repeat(40) @(posedge cmos_pclk_i); // H-Blanking
            end
            
            repeat(20) @(posedge cmos_pclk_i); // Vertical Front Porch
        end
    endtask

endmodule
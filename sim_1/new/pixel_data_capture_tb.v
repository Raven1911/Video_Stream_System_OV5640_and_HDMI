`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/26/2025 12:01:31 PM
// Design Name: 
// Module Name: pixel_data_capture_tb
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


module pixel_data_capture_tb;

    // Parameters (Must match DUT)
    localparam DATA_WIDTH = 8;

    // Clock definitions
    localparam T_CLK = 10;      // System clock period (10ns) -> 100 MHz
    localparam T_PCLK = 20;     // Camera clock period (20ns) -> 50 MHz (Asynchronous, slower)
    localparam RST_TIME = 20;   // Reset duration

    // Signals
    reg             clk_i;
    reg             resetn_i;

    reg             cam_pclk_i;
    reg [DATA_WIDTH-1:0] cam_half_pixel_i;
    reg             cam_href;
    reg             cam_vsync;

    wire            wr_pixel_o;
    wire [DATA_WIDTH*2-1:0] pixel_data_o;

    // Internal data check registers
    reg [DATA_WIDTH*2-1:0] expected_pixel_data;
    integer write_count = 0;
    integer pixel_idx = 0;

    // Instantiate the Unit Under Test (DUT)
    pixel_data_capture #(
        .DATA_WIDTH (DATA_WIDTH)
    ) dut (
        .clk_i              (clk_i),
        .resetn_i           (resetn_i),
        .cam_pclk_i         (cam_pclk_i),
        .cam_half_pixel_i   (cam_half_pixel_i),
        .cam_href           (cam_href),
        .cam_vsync          (cam_vsync),
        .wr_pixel_o         (wr_pixel_o),
        .pixel_data_o       (pixel_data_o)
    );

    // --- 1. Clock Generation ---

    // System Clock (clk_i)
    always #((T_CLK/2)) clk_i = ~clk_i;

    // Camera Pixel Clock (cam_pclk_i)
    always #((T_PCLK/2)) cam_pclk_i = ~cam_pclk_i;

    // --- 2. Input Stimulus Task ---

    // Task to generate one 8-bit half-pixel data cycle
    task drive_half_pixel;
        input [DATA_WIDTH-1:0] data;
        begin
            @(posedge cam_pclk_i) begin
                cam_half_pixel_i <= data;
            end
        end
    endtask

    // --- 3. Main Test Sequence ---

    initial begin
        // Initialization
        clk_i = 0;
        cam_pclk_i = 0;
        resetn_i = 0;
        cam_href = 0;
        cam_vsync = 1; // VSYNC high (Vertical Blanking/End of previous frame)
        cam_half_pixel_i = 8'h00;
        expected_pixel_data = 16'h0000;
        
        $display("---------------------------------------------------------------------------------");
        $display("Time | clk_i | cam_pclk_i | VSYNC | HREF | cam_data | State | wr_o | Pixel_o");
        $display("---------------------------------------------------------------------------------");

        // Assert Reset
        #RST_TIME resetn_i = 1;
        $display("[%0t] Reset released. Waiting for VSYNC falling edge...", $time);
        
        // --- VSYNC FALLING EDGE (Start of Frame) ---
        // VSYNC goes low, signaling the start of the active frame data
        #T_PCLK cam_vsync = 0; 
        $display("[%0t] VSYNC falls (Start of Frame).", $time);

        // Wait until the DUT FSM detects the VSYNC falling edge and transitions to BYTE1
        @(posedge clk_i);
        while (dut.pixel_state_reg != dut.BYTE1) @(posedge clk_i);
        $display("[%0t] FSM detected VSYNC falling edge and transitioned to BYTE1.", $time);


        // --- LINE 1: Capture 3 full 16-bit pixels (6 half-pixels) ---
        #T_PCLK cam_href = 1; // Start Horizontal Enable (Active Line)

        // PIXEL 1 (16-bit: 0xABCD)
        pixel_idx = 1;

        // Byte 1 (MSB: 0xAB)
        drive_half_pixel(8'hAB); 
        expected_pixel_data[15:8] = 8'hAB;
        @(posedge clk_i); // Wait for capture on pclk_rise_edge in clk_i domain
        $display("[%0t] P%0d B1: Half-pixel 0x%h captured.", $time, pixel_idx, cam_half_pixel_i);

        // Byte 2 (LSB: 0xCD)
        drive_half_pixel(8'hCD); 
        expected_pixel_data[7:0] = 8'hCD;
        @(posedge clk_i); // Wait for capture and transition to FIFO_WRITE
        $display("[%0t] P%0d B2: Half-pixel 0x%h captured. Expecting 0x%h on next FIFO_WRITE.", $time, pixel_idx, cam_half_pixel_i, expected_pixel_data);
        
        // Wait for FIFO_WRITE assert (should happen next clk_i cycle)
        @(posedge clk_i);
        write_count = write_count + 1;
        if (wr_pixel_o && (pixel_data_o == expected_pixel_data)) begin
            $display("[%0t] *** SUCCESS P%0d *** FIFO Write #%0d asserted. Data: 0x%h == 0x%h (Expected).", $time, pixel_idx, write_count, pixel_data_o, expected_pixel_data);
        end else begin
            $display("[%0t] !!! FAILURE P%0d !!! FIFO Write #%0d failed. Data: 0x%h != 0x%h (Expected).", $time, pixel_idx, write_count, pixel_data_o, expected_pixel_data);
        end

        // PIXEL 2 (16-bit: 0x1234)
        pixel_idx = 2;
        // Byte 1 (MSB: 0x12)
        drive_half_pixel(8'h12); 
        expected_pixel_data[15:8] = 8'h12;
        @(posedge clk_i);
        $display("[%0t] P%0d B1: Half-pixel 0x%h captured.", $time, pixel_idx, cam_half_pixel_i);

        // Byte 2 (LSB: 0x34)
        drive_half_pixel(8'h34); 
        expected_pixel_data[7:0] = 8'h34;
        @(posedge clk_i);
        $display("[%0t] P%0d B2: Half-pixel 0x%h captured. Expecting 0x%h on next FIFO_WRITE.", $time, pixel_idx, cam_half_pixel_i, expected_pixel_data);

        // Wait for FIFO_WRITE assert
        @(posedge clk_i);
        write_count = write_count + 1;
        if (wr_pixel_o && (pixel_data_o == expected_pixel_data)) begin
            $display("[%0t] *** SUCCESS P%0d *** FIFO Write #%0d asserted. Data: 0x%h == 0x%h (Expected).", $time, pixel_idx, write_count, pixel_data_o, expected_pixel_data);
        end else begin
            $display("[%0t] !!! FAILURE P%0d !!! FIFO Write #%0d failed. Data: 0x%h != 0x%h (Expected).", $time, pixel_idx, write_count, pixel_data_o, expected_pixel_data);
        end
        
        // PIXEL 3 (16-bit: 0xFEED)
        pixel_idx = 3;
        // Byte 1 (MSB: 0xFE)
        drive_half_pixel(8'hFE); 
        expected_pixel_data[15:8] = 8'hFE;
        @(posedge clk_i);
        $display("[%0t] P%0d B1: Half-pixel 0x%h captured.", $time, pixel_idx, cam_half_pixel_i);

        // Byte 2 (LSB: 0xED)
        drive_half_pixel(8'hED); 
        expected_pixel_data[7:0] = 8'hED;
        @(posedge clk_i);
        $display("[%0t] P%0d B2: Half-pixel 0x%h captured. Expecting 0x%h on next FIFO_WRITE.", $time, pixel_idx, cam_half_pixel_i, expected_pixel_data);

        // Wait for FIFO_WRITE assert
        @(posedge clk_i);
        write_count = write_count + 1;
        if (wr_pixel_o && (pixel_data_o == expected_pixel_data)) begin
            $display("[%0t] *** SUCCESS P%0d *** FIFO Write #%0d asserted. Data: 0x%h == 0x%h (Expected).", $time, pixel_idx, write_count, pixel_data_o, expected_pixel_data);
        end else begin
            $display("[%0t] !!! FAILURE P%0d !!! FIFO Write #%0d failed. Data: 0x%h != 0x%h (Expected).", $time, pixel_idx, write_count, pixel_data_o, expected_pixel_data);
        end

        // --- End of Line 1 ---
        #T_PCLK cam_href = 0; // End Horizontal Enable (Horizontal Blanking)
        $display("[%0t] HREF de-asserted (End of Line 1).", $time);

        // Idle period
        #(2*T_PCLK);
        
        // --- Start of Line 2 (Only 1 pixel) ---
        #T_PCLK cam_href = 1; // Start Horizontal Enable (Active Line)

        // PIXEL 4 (16-bit: 0xBEEF)
        pixel_idx = 4;
        // Byte 1 (MSB: 0xBE)
        drive_half_pixel(8'hBE); 
        expected_pixel_data[15:8] = 8'hBE;
        @(posedge clk_i);
        $display("[%0t] P%0d B1: Half-pixel 0x%h captured.", $time, pixel_idx, cam_half_pixel_i);

        // Byte 2 (LSB: 0xEF)
        drive_half_pixel(8'hEF); 
        expected_pixel_data[7:0] = 8'hEF;
        @(posedge clk_i);
        $display("[%0t] P%0d B2: Half-pixel 0x%h captured. Expecting 0x%h on next FIFO_WRITE.", $time, pixel_idx, cam_half_pixel_i, expected_pixel_data);

        // Wait for FIFO_WRITE assert
        @(posedge clk_i);
        write_count = write_count + 1;
        if (wr_pixel_o && (pixel_data_o == expected_pixel_data)) begin
            $display("[%0t] *** SUCCESS P%0d *** FIFO Write #%0d asserted. Data: 0x%h == 0x%h (Expected).", $time, pixel_idx, write_count, pixel_data_o, expected_pixel_data);
        end else begin
            $display("[%0t] !!! FAILURE P%0d !!! FIFO Write #%0d failed. Data: 0x%h != 0x%h (Expected).", $time, pixel_idx, write_count, pixel_data_o, expected_pixel_data);
        end
        
        // --- End of Line 2 and End of Frame ---
        #T_PCLK cam_href = 0; // End Horizontal Enable
        $display("[%0t] HREF de-asserted (End of Line 2).", $time);
        
        #T_PCLK cam_vsync = 1; // VSYNC high (Vertical Blanking/End of frame)
        $display("[%0t] VSYNC asserts (End of Frame).", $time);

        // Wait for FSM to reset to VSYNC_FEDGE
        @(posedge clk_i);
        while (dut.pixel_state_reg != dut.VSYNC_FEDGE) @(posedge clk_i);
        $display("[%0t] FSM returned to VSYNC_FEDGE, ready for next frame.", $time);


        // Finish Simulation
        #(4*T_PCLK) $display("[%0t] Simulation Finished. Total 4 pixels captured.", $time);
        $finish;
    end
    
    // Display FSM state changes (Optional, for debugging)
    /*
    always @(posedge clk_i) begin
        if (dut.pixel_state_reg != dut.pixel_state_next) begin
            $display("[%0t] CLK_I: State change detected: %d -> %d", $time, dut.pixel_state_reg, dut.pixel_state_next);
        end
    end
    */

endmodule


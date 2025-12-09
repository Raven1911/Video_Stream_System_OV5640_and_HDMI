`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/25/2025 06:25:32 PM
// Design Name: 
// Module Name: pixel_data_capture
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

module pixel_data_capture#(
    parameter DATA_WIDTH = 8
)(  
    // System Clock Domain
    input                           clk_i,      // System clock (Faster than cam_pclk_i)
    input                           resetn_i,   // Asynchronous reset (active low)

    // Camera Interface (Asynchronous to clk_i)
    input                           cam_pclk_i,
    input   [DATA_WIDTH-1:0]        cam_half_pixel_i, // Incoming 8-bit pixel data
    input                           cam_href,   // Horizontal Enable
    input                           cam_vsync,  // Vertical Sync

    // Output Ports (Synchronous to clk_i)
    output  reg                             wr_pixel_o,            // FIFO write enable
    output          [DATA_WIDTH*2-1:0]      pixel_data_o           // 16-bit combined pixel
);

    // --- 1. Internal Registers and FSM Definitions ---

    // FSM state declarations
    localparam      VSYNC_FEDGE = 2'd0,   // Wait for VSYNC falling edge (Frame start)
                    BYTE1       = 2'd1,   // Capture MSB (Byte 1)
                    BYTE2       = 2'd2,   // Capture LSB (Byte 2)
                    FIFO_WRITE  = 2'd3;   // Assert write signal

    reg     [1:0]               pixel_state_next, pixel_state_reg;
    reg     [DATA_WIDTH*2-1:0]  pixel_data_next, pixel_data_reg;

    // 2-Flop Synchronizers for Control Signals (CDC)
    reg                         pclk_1, pclk_2;  // For cam_pclk_i
    reg                         href_1, href_2;  // For cam_href
    reg                         vsync_1, vsync_2; // For cam_vsync

    // Register for Synchronized Data
    //reg     [DATA_WIDTH-1:0]    cam_data_synced_reg; // Holds the 8-bit data captured on PCLK rise

    // --- 2. Clocked Logic (Registers) ---

    // Detect PCLK rising edge (synchronized)
    wire pclk_rise_edge = pclk_1 & ~pclk_2;

    always @(posedge clk_i or negedge resetn_i) begin
        if (~resetn_i) begin
            // Reset FSM
            pixel_state_reg     <=  VSYNC_FEDGE;
            pixel_data_reg      <=  0;
            // Reset Synchronizers
            pclk_1 <= 0;
            pclk_2 <= 0;
            href_1 <= 0;
            href_2 <= 0;
            vsync_1 <= 0;
            vsync_2 <= 0;
        end
        else begin
            // FSM State Update
            pixel_state_reg <= pixel_state_next;
            pixel_data_reg  <=  pixel_data_next;

            // Control Signal Synchronization (2-flop chain)
            pclk_1          <=  cam_pclk_i; 
            pclk_2          <=  pclk_1;
            href_1          <=  cam_href;
            href_2          <=  href_1;
            vsync_1         <=  cam_vsync;
            vsync_2         <=  vsync_1;
        end
    end

    // --- 3. Combinational Logic (FSM Next State and Output) ---

    always @(*) begin
        pixel_data_next = pixel_data_reg;
        pixel_state_next = pixel_state_reg;
        wr_pixel_o = 0; // Default output is low

        case (pixel_state_reg)
            VSYNC_FEDGE: begin
                // VSYNC falling edge (Frame start: 1->0)
                if(vsync_1 == 1'b0 && vsync_2 == 1'b1) begin 
                    // Start frame capture on the next PCLK rise
                    pixel_state_next = BYTE1; 
                end
            end

            BYTE1: begin
                // Check for PCLK rising edge and HREF active (within active line)
                if(pclk_1==1 && pclk_2==0 && href_1==1 && href_2==1) begin 
                    pixel_data_next[DATA_WIDTH*2-1:DATA_WIDTH] = cam_half_pixel_i;
                    pixel_state_next = BYTE2;
                end
                // Check for Frame End (VSYNC rising edge or going high in VBLANK)
                else if(vsync_1==1 && vsync_2==1) begin
                    pixel_state_next = VSYNC_FEDGE;
                end
            end

            BYTE2: begin
                // Check for PCLK rising edge and HREF active (next clock cycle)
                if(pclk_1==1 && pclk_2==0 && href_1==1 && href_2==1) begin 
                    pixel_data_next[DATA_WIDTH-1:0] = cam_half_pixel_i;
                    pixel_state_next = FIFO_WRITE;
                end
                // Check for Frame End
                else if(vsync_1==1 && vsync_2==1) begin
                    pixel_state_next = VSYNC_FEDGE;
                end
            end

            FIFO_WRITE: begin 
                // Assert write signal for one clock cycle
                wr_pixel_o = 1;
                // Move back to capture the MSB of the next pixel
                pixel_state_next = BYTE1; 
            end

            default: pixel_state_next = VSYNC_FEDGE;
        endcase
    end

    assign pixel_data_o = pixel_data_reg;

endmodule


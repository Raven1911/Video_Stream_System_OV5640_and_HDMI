    `timescale 1ns / 1ps
    //////////////////////////////////////////////////////////////////////////////////
    // Company: 
    // Engineer: 
    // 
    // Create Date: 10/28/2025 01:22:23 PM
    // Design Name: 
    // Module Name: control_frame_buffer
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

module control_frame_buffer#(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 16
)(
    input                           clk_i,
    input                           resetn_i,

    input       [15:0]              resolution_width_i,
    input       [15:0]              resolution_depth_i,

    // empty_i: '1' -> FIFO vào RỖNG (Không thể Ghi)
    input                           empty_i, 
    // full_i: '1' -> FIFO ra ĐẦY (Không thể Đọc)
    input                           full_i,  

    output                          wr_o,
    output                          rd_o,
    output      [ADDR_WIDTH-1:0]    addr_wr_o,
    output      [ADDR_WIDTH-1:0]    addr_rd_o
);

    //================================================================
    // Tính toán địa chỉ
    //================================================================
    wire    [ADDR_WIDTH-1:0]  total_pixel;
    // Địa chỉ pixel cuối cùng
    assign  total_pixel = (resolution_width_i * resolution_depth_i) - 1; 

    //================================================================
    // Registers
    //================================================================
    
    // Con trỏ Ghi hiện tại
    reg     [31:0]  count_pixel_wr_reg, count_pixel_wr_next;
    
    // Con trỏ Đọc (là con trỏ Ghi của chu kỳ trước)
    reg     [31:0]  count_pixel_rd_reg, count_pixel_rd_next;
    
    // Cờ báo hiệu: "Đã ghi ít nhất 1 lần, cho phép Đọc"
    reg             pipeline_primed_reg, pipeline_primed_next;

    //================================================================
    // Tín hiệu Enable (Tổ hợp)
    //================================================================
    
    // Ghi NẾU đầu vào không rỗng
    assign wr_o = (empty_i == 0); 
    
    // Đọc NẾU pipeline đã được mồi VÀ đầu ra không đầy
    assign rd_o = (pipeline_primed_reg == 1'b1) && (full_i == 0);

    //================================================================
    // Khối Sequential (Register)
    //================================================================
    always @(posedge clk_i, negedge resetn_i) begin
        if (~resetn_i) begin
            count_pixel_wr_reg <= 0;
            count_pixel_rd_reg <= 0;
            pipeline_primed_reg <= 1'b0;
        end
        else begin
            count_pixel_wr_reg <= count_pixel_wr_next;
            count_pixel_rd_reg <= count_pixel_rd_next;
            pipeline_primed_reg <= pipeline_primed_next;
        end
    end

    //================================================================
    // Khối Tổ hợp (Logic con trỏ)
    //================================================================
    always @(*) begin
        // Mặc định: giữ nguyên
        count_pixel_wr_next = count_pixel_wr_reg;
        count_pixel_rd_next = count_pixel_rd_reg;
        pipeline_primed_next = pipeline_primed_reg;

        // --- Logic Ghi (Write) ---
        // Nếu Ghi được phép (đầu vào có data)
        if (wr_o == 1'b1) begin
            
            // Tăng con trỏ Ghi cho chu kỳ TỚI
            if (count_pixel_wr_reg == total_pixel) begin
                count_pixel_wr_next = 0;
            end else begin
                count_pixel_wr_next = count_pixel_wr_reg + 1;
            end
            
            // Đặt cờ "mồi" để cho phép Đọc ở chu kỳ TỚI
            pipeline_primed_next = 1'b1;
        end
        else pipeline_primed_next = 1'b0;
        
        // --- Logic Đọc (Read) ---
        // Con trỏ Đọc LUÔN LUÔN là con trỏ Ghi của chu kỳ này
        // (để nó trở thành con trỏ Ghi của chu kỳ TRƯỚC ở chu kỳ tới)
        count_pixel_rd_next = count_pixel_wr_reg;
    end

    //================================================================
    // Output Assignments
    //================================================================
    
    // Địa chỉ Ghi là con trỏ Ghi hiện tại
    assign addr_wr_o = count_pixel_wr_reg;
    
    // Địa chỉ Đọc là con trỏ Đọc hiện tại (chính là con trỏ Ghi đã bị trễ 1 chu kỳ)
    assign addr_rd_o = count_pixel_rd_reg;

endmodule


`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/16/2025 01:50:25 PM
// Design Name: 
// Module Name: control_frame_buffer_write_only
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
module control_frame_buffer_write_only#(
    parameter ADDR_WIDTH = 32
)(
    input                               clk_i,
    input                               resetn_i,

    input       [15:0]                  resolution_width_i,
    input       [15:0]                  resolution_depth_i,

    // empty_i: '1' -> FIFO vào RỖNG (Không thể Ghi)
    input                               empty_i, 

    // wr_o: '1' -> Cho phép Ghi vào Frame Buffer (ĐỒNG BỘ)
    output                              wr_o,
    // addr_wr_o: Địa chỉ Ghi hiện tại (ĐỒNG BỘ)
    output      [ADDR_WIDTH-1:0]        addr_wr_o,
    // page_written_once_o: '1' -> Báo đã ghi xong ít nhất 1 trang, giữ nguyên
    output                              page_written_once_o
);

    //================================================================
    // Tính toán địa chỉ
    //================================================================
    
    // total_pixel: Lưu địa chỉ của pixel cuối cùng
    wire    [ADDR_WIDTH-1:0]    total_pixel;
    assign  total_pixel = (resolution_width_i * resolution_depth_i) - 1; 

    //================================================================
    // Registers
    //================================================================
    
    // Con trỏ Ghi (lưu địa chỉ *tiếp theo* sẽ được ghi)
    reg     [ADDR_WIDTH-1:0]  count_pixel_wr_reg, count_pixel_wr_next;
    
    // Cờ báo đã ghi xong ít nhất 1 trang
    reg                       page_written_once_reg, page_written_once_next;

    // Thanh ghi cho các đầu ra đồng bộ
    reg     [ADDR_WIDTH-1:0]  addr_wr_o_reg, addr_wr_o_next;
    reg                       wr_o_reg, wr_o_next;

    //================================================================
    // Khối Sequential (Register)
    //================================================================
    
    // Lưu trữ giá trị con trỏ Ghi và cờ báo
    always @(posedge clk_i, negedge resetn_i) begin
        if (~resetn_i) begin
            // Reset con trỏ về địa chỉ 0
            count_pixel_wr_reg <= {ADDR_WIDTH{1'b0}};
            // Reset cờ báo
            page_written_once_reg <= 1'b0;
            
            // Reset các đầu ra đồng bộ
            addr_wr_o_reg <= {ADDR_WIDTH{1'b0}};
            wr_o_reg <= 1'b0;
        end
        else begin
            // Cập nhật con trỏ Ghi ở mỗi sườn clk
            count_pixel_wr_reg <= count_pixel_wr_next;
            // Cập nhật cờ báo
            page_written_once_reg <= page_written_once_next;
            
            // Cập nhật các đầu ra đồng bộ
            addr_wr_o_reg <= addr_wr_o_next;
            wr_o_reg <= wr_o_next;
        end
    end

    // Điều kiện để ghi (tổ hợp)
    wire write_condition;
    assign  write_condition = (empty_i == 0);
    //================================================================
    // Khối Tổ hợp (Logic con trỏ Ghi)
    //================================================================
    always @(*) begin
        // Mặc định: giữ nguyên giá trị con trỏ
        count_pixel_wr_next = count_pixel_wr_reg;
        // Mặc định: giữ nguyên cờ báo
        page_written_once_next = page_written_once_reg;
        
        // Mặc định cho đầu ra: Không ghi
        addr_wr_o_next = addr_wr_o_reg; // Giữ nguyên giá trị cũ
        wr_o_next = 1'b0;
        
        
        // --- Logic Ghi (Write) ---
        // Nếu Ghi được phép (đầu vào có data)
        if (write_condition == 1'b1) begin
            // Set tín hiệu Ghi cho chu kỳ TỚI
            wr_o_next = 1'b1;
            // Set địa chỉ Ghi cho chu kỳ TỚI (là địa chỉ của con trỏ HIỆN TẠI)
            addr_wr_o_next = count_pixel_wr_reg;
            
            // Tăng con trỏ Ghi cho chu kỳ TỚI
            if (count_pixel_wr_reg == total_pixel) begin
                // Nếu đang ở pixel cuối, quay vòng về 0
                count_pixel_wr_next = {ADDR_WIDTH{1'b0}};
            end else begin
                // Nếu không, tăng lên 1
                count_pixel_wr_next = count_pixel_wr_reg + 1;
            end
            
            // --- Logic Cờ báo ---
            // Nếu hiện tại ĐANG CÓ ĐIỀU KIỆN GHI (write_condition) VÀ đang ở PIXEL CUỐI
            if (count_pixel_wr_reg == total_pixel) begin
                page_written_once_next = 1'b1;
            end
        end
        // Nếu không ghi (write_condition = 0), thì:
        // - wr_o_next = 1'b0 (theo mặc định)
        // - addr_wr_o_next = addr_wr_o_reg (theo mặc định)
        // - count_pixel_wr_next = count_pixel_wr_reg (theo mặc định)

        // Đảm bảo cờ báo đã set thì không bị clear
        if (page_written_once_reg == 1'b1) begin
            page_written_once_next = 1'b1;
        end
    end

    //================================================================
    // Output Assignments
    //================================================================
    
    // Gán các đầu ra đồng bộ
    assign addr_wr_o = addr_wr_o_reg;
    assign wr_o = wr_o_reg;
    
    // Gán đầu ra cho cờ báo (đã được đăng ký)
    assign page_written_once_o = page_written_once_reg;

endmodule

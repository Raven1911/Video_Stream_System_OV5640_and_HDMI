`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/16/2025 02:11:29 PM
// Design Name: 
// Module Name: control_frame_buffer_read_only
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


// module control_frame_buffer_read_only#(
//     parameter ADDR_WIDTH = 32,
//     // Số chu kỳ xen kẽ. 
//     // 1 = Đọc mỗi chu kỳ. 
//     // 2 = Đọc 1 chu kỳ, nghỉ 1 chu kỳ.
//     // 3 = Đọc 1 chu kỳ, nghỉ 2 chu kỳ.
//     parameter READ_STROBE_PERIOD = 4,
//     parameter FIFO_DEPTH_WIDTH = 8
// )(
//     input                               clk_i,
//     input                               resetn_i,

//     input       [15:0]                  resolution_width_i,
//     input       [15:0]                  resolution_depth_i,

//     // page_written_once_i: '1' -> Báo hiệu từ module Ghi là đã ghi xong 1 trang
//     input                               page_written_once_i,
//     // full_i: '1' -> FIFO đầu ra ĐẦY (Không thể Đọc)
//     input                               full_i,
//     input        [FIFO_DEPTH_WIDTH-1:0] data_count_w_i,

//     // rd_o: '1' -> Cho phép Đọc từ Frame Buffer (ĐỒNG BỘ)
//     output                              rd_o,
//     // addr_rd_o: Địa chỉ Đọc hiện tại (ĐỒNG BỘ)
//     output      [ADDR_WIDTH-1:0]        addr_rd_o
// );

//     //================================================================
//     // Tính toán địa chỉ
//     //================================================================
    
//     // total_pixel: Lưu địa chỉ của pixel cuối cùng
//     wire    [ADDR_WIDTH-1:0]    total_pixel;
//     assign  total_pixel = (resolution_width_i * resolution_depth_i) - 1; 

//     // Tính toán độ rộng cho bộ đếm strobe
//     localparam STROBE_CNT_WIDTH = (READ_STROBE_PERIOD < 2) ? 1 : $clog2(READ_STROBE_PERIOD);

//     //================================================================
//     // Registers
//     //================================================================
    
//     // Con trỏ Đọc (lưu địa chỉ *tiếp theo* sẽ được đọc)
//     reg     [ADDR_WIDTH-1:0]  count_pixel_rd_reg, count_pixel_rd_next;
    
//     // Cờ báo "sticky" cho phép bắt đầu đọc (khi page_written_once_i đã lên 1)
//     reg                       read_enabled_reg, read_enabled_next;

//     // Thanh ghi cho các đầu ra đồng bộ
//     reg     [ADDR_WIDTH-1:0]  addr_rd_o_reg, addr_rd_o_next;
//     reg                       rd_o_reg, rd_o_next;

//     // Bộ đếm cho chu kỳ xen kẽ (strobe)
//     reg     [STROBE_CNT_WIDTH-1:0] read_strobe_cnt_reg, read_strobe_cnt_next;

//     //================================================================
//     // Khối Sequential (Register)
//     //================================================================
    
//     always @(posedge clk_i, negedge resetn_i) begin
//         if (~resetn_i) begin
//             // Reset con trỏ về địa chỉ 0
//             count_pixel_rd_reg <= {ADDR_WIDTH{1'b0}};
//             // Reset cờ báo cho phép đọc
//             read_enabled_reg <= 1'b0;
            
//             // Reset các đầu ra đồng bộ
//             addr_rd_o_reg <= {ADDR_WIDTH{1'b0}};
//             rd_o_reg <= 1'b0;
            
//             // Reset bộ đếm strobe về 0
//             read_strobe_cnt_reg <= {STROBE_CNT_WIDTH{1'b0}};
//         end
//         else begin
//             // Cập nhật con trỏ Đọc
//             count_pixel_rd_reg <= count_pixel_rd_next;
//             // Cập nhật cờ báo cho phép đọc
//             read_enabled_reg <= read_enabled_next;
            
//             // Cập nhật các đầu ra đồng bộ
//             addr_rd_o_reg <= addr_rd_o_next;
//             rd_o_reg <= rd_o_next;
            
//             // Cập nhật bộ đếm strobe
//             read_strobe_cnt_reg <= read_strobe_cnt_next;
//         end
//     end

//     // Tín hiệu tổ hợp: Điều kiện cơ bản để đọc (đã enable VÀ FIFO không đầy)
//     wire can_read_base;
//     assign can_read_base = (read_enabled_reg == 1'b1) && (full_i == 1'b0);
    
//     // Tín hiệu tổ hợp: Có phải chu kỳ strobe cho phép đọc không?
//     wire read_strobe_allow;
//     assign read_strobe_allow = (read_strobe_cnt_reg == 0);

//     //================================================================
//     // Khối Tổ hợp (Logic con trỏ Đọc)
//     //================================================================
//     always @(*) begin
//         // Mặc định: giữ nguyên giá trị con trỏ
//         count_pixel_rd_next = count_pixel_rd_reg;
//         // Mặc định: giữ nguyên bộ đếm strobe
//         read_strobe_cnt_next = read_strobe_cnt_reg;
        
//         // Mặc định cho đầu ra: Không đọc
//         addr_rd_o_next = addr_rd_o_reg; // Giữ nguyên giá trị cũ
//         rd_o_next = 1'b0;
        
//         // Logic cờ "bắt đầu đọc"
//         // Cờ này sẽ lên 1 khi page_written_once_i lên 1, và giữ ở đó
//         read_enabled_next = read_enabled_reg | page_written_once_i;
        
        
//         // --- Logic Đọc (Read) ---
//         // Nếu điều kiện cơ bản cho phép đọc
//         if (can_read_base == 1'b1) begin
//             // Cập nhật bộ đếm strobe (nó chỉ đếm khi 'can_read_base' = 1)
//             if (READ_STROBE_PERIOD > 1) begin
//                 if (read_strobe_cnt_reg == READ_STROBE_PERIOD - 1) begin
//                     read_strobe_cnt_next = 0;
//                 end else begin
//                     read_strobe_cnt_next = read_strobe_cnt_reg + 1;
//                 end
//             end
//             // else (PERIOD <= 1), bộ đếm luôn giữ = 0

//             // --- Logic Đọc chính ---
//             // Nếu đây LÀ chu kỳ strobe cho phép
//             if (read_strobe_allow == 1'b1) begin
//                 // Set tín hiệu Đọc cho chu kỳ TỚI
//                 rd_o_next = 1'b1;
//                 // Set địa chỉ Đọc cho chu kỳ TỚI (là địa chỉ của con trỏ HIỆN TẠI)
//                 addr_rd_o_next = count_pixel_rd_reg;
            
//                 // Tăng con trỏ Đọc cho chu kỳ TỚI
//                 if (count_pixel_rd_reg == total_pixel) begin
//                     // Nếu đang ở pixel cuối, quay vòng về 0
//                     count_pixel_rd_next = {ADDR_WIDTH{1'b0}};
//                 end else begin
//                     // Nếu không, tăng lên 1
//                     count_pixel_rd_next = count_pixel_rd_reg + 1;
//                 end
//             end
//             // Nếu không phải chu kỳ strobe (read_strobe_allow == 0):
//             // - rd_o_next = 1'b0 (theo mặc định)
//             // - addr_rd_o_next = addr_rd_o_reg (theo mặc định)
//             // - count_pixel_rd_next = count_pixel_rd_reg (theo mặc định)
//             // Tức là: chỉ đếm strobe, không tăng con trỏ địa chỉ
//         end
//         // Nếu 'can_read_base' là 0 (hoặc chưa enable, hoặc FIFO đầy):
//         // - Tất cả các con trỏ và bộ đếm đều giữ nguyên (theo mặc định)
//         // - Đầu ra rd_o = 0 (theo mặc định)
//     end

//     //================================================================
//     // Output Assignments
//     //================================================================
    
//     // Gán các đầu ra đồng bộ
//     assign addr_rd_o = addr_rd_o_reg;
//     assign rd_o = rd_o_reg;

// endmodule





module control_frame_buffer_read_only#(
    parameter ADDR_WIDTH = 32,
    parameter READ_STROBE_PERIOD = 4,
    parameter FIFO_DEPTH_WIDTH = 9,
    // Các ngưỡng điều khiển FIFO
    parameter THRESHOLD_HIGH = 500,
    parameter THRESHOLD_LOW  = 400
)(
    input                               clk_i,
    input                               resetn_i,

    input       [15:0]                  resolution_width_i,
    input       [15:0]                  resolution_depth_i,

    // page_written_once_i: '1' -> Báo hiệu từ module Ghi là đã ghi xong 1 trang
    input                               page_written_once_i,
    // data_count_w_i: Số lượng word hiện có trong FIFO
    input       [FIFO_DEPTH_WIDTH-1:0]  data_count_w_i,
    // full_i: Giữ lại như một tín hiệu bảo vệ (Hard Full)
    input                               full_i,

    // rd_o: '1' -> Cho phép Đọc từ Frame Buffer (Ghi vào FIFO)
    output                              rd_o,
    // addr_rd_o: Địa chỉ Đọc hiện tại
    output      [ADDR_WIDTH-1:0]        addr_rd_o
);

    //================================================================
    // Tính toán thông số
    //================================================================
    wire    [ADDR_WIDTH-1:0]    total_pixel;
    assign  total_pixel = (resolution_width_i * resolution_depth_i) - 1; 

    localparam STROBE_CNT_WIDTH = (READ_STROBE_PERIOD < 2) ? 1 : $clog2(READ_STROBE_PERIOD);

    //================================================================
    // Registers
    //================================================================
    reg     [ADDR_WIDTH-1:0]  count_pixel_rd_reg, count_pixel_rd_next;
    reg                       read_enabled_reg, read_enabled_next;
    reg     [ADDR_WIDTH-1:0]  addr_rd_o_reg, addr_rd_o_next;
    reg                       rd_o_reg, rd_o_next;
    reg     [STROBE_CNT_WIDTH-1:0] read_strobe_cnt_reg, read_strobe_cnt_next;

    // Thanh ghi trạng thái tạm dừng FIFO (Hysteresis state)
    reg                       fifo_pause_reg, fifo_pause_next;

    //================================================================
    // Khối Sequential (Register)
    //================================================================
    always @(posedge clk_i, negedge resetn_i) begin
        if (~resetn_i) begin
            count_pixel_rd_reg  <= {ADDR_WIDTH{1'b0}};
            read_enabled_reg    <= 1'b0;
            addr_rd_o_reg       <= {ADDR_WIDTH{1'b0}};
            rd_o_reg            <= 1'b0;
            read_strobe_cnt_reg <= {STROBE_CNT_WIDTH{1'b0}};
            fifo_pause_reg      <= 1'b0; // Mặc định ban đầu không tạm dừng
        end
        else begin
            count_pixel_rd_reg  <= count_pixel_rd_next;
            read_enabled_reg    <= read_enabled_next;
            addr_rd_o_reg       <= addr_rd_o_next;
            rd_o_reg            <= rd_o_next;
            read_strobe_cnt_reg <= read_strobe_cnt_next;
            fifo_pause_reg      <= fifo_pause_next;
        end
    end

    //================================================================
    // Khối Tổ hợp Logic
    //================================================================
    
    // 1. Logic Hysteresis cho FIFO
    always @(*) begin
        fifo_pause_next = fifo_pause_reg;
        
        if (data_count_w_i >= THRESHOLD_HIGH) begin
            // Nếu vượt ngưỡng cao hoặc FIFO Full thực tế -> Tạm dừng đọc
            fifo_pause_next = 1'b1;
        end 
        else if (data_count_w_i <= THRESHOLD_LOW) begin
            // Nếu giảm xuống dưới ngưỡng thấp -> Cho phép đọc lại
            fifo_pause_next = 1'b0;
        end
    end

    // 2. Điều kiện cơ bản để đọc: 
    // - Đã được enable (page_written_once_i đã từng lên 1)
    // - FIFO không ở trạng thái tạm dừng (pause)
    // - FIFO không bị Full cứng (bảo vệ thêm)
    wire can_read_base;
    assign can_read_base = (read_enabled_reg == 1'b1) && (fifo_pause_next == 1'b0) && (full_i == 1'b0);
    
    wire read_strobe_allow;
    assign read_strobe_allow = (read_strobe_cnt_reg == 0);

    always @(*) begin
        // Mặc định
        count_pixel_rd_next  = count_pixel_rd_reg;
        read_strobe_cnt_next = read_strobe_cnt_reg;
        addr_rd_o_next       = addr_rd_o_reg;
        rd_o_next            = 1'b0;
        
        // Sticky bit cho phép đọc sau khi có trang đầu tiên
        read_enabled_next = read_enabled_reg | page_written_once_i;
        
        if (can_read_base) begin
            // Logic bộ đếm Strobe (Xen kẽ chu kỳ)
            if (READ_STROBE_PERIOD > 1) begin
                if (read_strobe_cnt_reg == READ_STROBE_PERIOD - 1)
                    read_strobe_cnt_next = 0;
                else
                    read_strobe_cnt_next = read_strobe_cnt_reg + 1;
            end

            // Thực hiện đọc dữ liệu
            if (read_strobe_allow) begin
                rd_o_next = 1'b1;
                addr_rd_o_next = count_pixel_rd_reg;
            
                // Tăng địa chỉ hoặc quay vòng
                if (count_pixel_rd_reg == total_pixel)
                    count_pixel_rd_next = {ADDR_WIDTH{1'b0}};
                else
                    count_pixel_rd_next = count_pixel_rd_reg + 1;
            end
        end
    end

    // Gán đầu ra
    assign addr_rd_o = addr_rd_o_reg;
    assign rd_o = rd_o_reg;

endmodule

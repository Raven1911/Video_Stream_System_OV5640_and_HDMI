`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/26/2025 05:17:15 PM
// Design Name: 
// Module Name: frame_buffer
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



module frame_buffer#(
    parameter ADDR_WIDTH    = 32,
    parameter DATA_WIDTH    = 16,
    parameter NUMBER_BRAM   = 75,
    parameter DEPTH_SIZE    = 4096, // size bram = (DATA_WIDTH * DEPTH_SIZE)/8 (Byte)
    parameter MODE = 2,     // MOD 0 SINGLE PORT READ_WRITE
                            // MOD 1 DUAL PORT READ_WRITE // erro
                            // MOD 2 DUAL PORT READ / SINGLE PORT WRITE
    parameter ENB_TEST_PATTERN = 1
)(  

    input                               clk_i,
    input                               resetn_i,

    input                               wr0_i,
    input                               wr1_i,

    input           [ADDR_WIDTH-1:0]    addr_wr0, //address global
    input           [ADDR_WIDTH-1:0]    addr_wr1, //address global
    input           [ADDR_WIDTH-1:0]    addr_rd0, //address global
    input           [ADDR_WIDTH-1:0]    addr_rd1, //address global

    input           [DATA_WIDTH-1:0]    Data_in0,
    input           [DATA_WIDTH-1:0]    Data_in1,
    output          [DATA_WIDTH-1:0]    Data_out0,
    output          [DATA_WIDTH-1:0]    Data_out1

    );

    generate
        if (MODE == 0) begin
            wire            [NUMBER_BRAM-1:0]                    s_wr_in;
            wire            [NUMBER_BRAM*ADDR_WIDTH-1:0]         s_addr_wr;  // address local for each BRAM
            wire            [NUMBER_BRAM*ADDR_WIDTH-1:0]         s_addr_rd;  // address local for each BRAM
            wire            [NUMBER_BRAM*DATA_WIDTH-1:0]         s_Data_in;
            wire            [NUMBER_BRAM*DATA_WIDTH-1:0]         s_Data_out;
            wire            [NUMBER_BRAM-1:0]                    ID_bram_selected;

            



            decoder_frame_buffer#(
                .ADDR_WIDTH(ADDR_WIDTH),
                .DATA_WIDTH(DATA_WIDTH),
                .NUMBER_BRAM(NUMBER_BRAM),
                .DEPTH_SIZE(DEPTH_SIZE)
            )decoder_frame_buffer_uut(
                //input mem
                .wr_i(wr0_i),
                .addr_wr(addr_wr0),
                .addr_rd(addr_rd0),
                .Data_in(Data_in0),
            //decoder port for each bram
                .s_wr_in_o(s_wr_in), 
                .s_addr_wr_o(s_addr_wr),
                .s_addr_rd_o(s_addr_rd),
                .s_Data_in_o(s_Data_in),
                .ID_bram_selected_rd_o(ID_bram_selected)
            );

            // gen block ram
            genvar bram_count;
            // generate
                for (bram_count = 0; bram_count < NUMBER_BRAM; bram_count = bram_count + 1) begin : g_bram
                    wire [ADDR_WIDTH-1:0]  aw = s_addr_wr [((ADDR_WIDTH*bram_count)+ADDR_WIDTH-1) -: ADDR_WIDTH];
                    wire [ADDR_WIDTH-1:0]  ar = s_addr_rd [((ADDR_WIDTH*bram_count)+ADDR_WIDTH-1) -: ADDR_WIDTH];
                    wire [DATA_WIDTH-1:0]  din = s_Data_in [((DATA_WIDTH*bram_count)+DATA_WIDTH-1) -: DATA_WIDTH];
                    wire                   we  = s_wr_in[bram_count];

                    block_ram_frame_buffer0 #(
                        .ADDR_WIDTH (ADDR_WIDTH),   // có thể giảm xuống $clog2(DEPTH_SIZE) nếu muốn gọn địa chỉ local
                        .DATA_WIDTH (DATA_WIDTH),
                        .DEPTH_SIZE (DEPTH_SIZE)
                    ) u_bram (
                        .clk_i    (clk_i),
                        .wr_i     (we),
                        .addr_wr  (aw   - (DEPTH_SIZE*bram_count)),
                        .addr_rd  (ar   - (DEPTH_SIZE*bram_count)),
                        .Data_in  (din),
                        .Data_out (s_Data_out[((DATA_WIDTH*bram_count)+DATA_WIDTH-1) -: DATA_WIDTH])
                    );
                end
            // endgenerate

            encoder_frame_buffer#(
                .DATA_WIDTH(DATA_WIDTH),
                .NUMBER_BRAM(NUMBER_BRAM)
            )encoder_frame_buffer_uut(
                .clk_i(clk_i),
                .resetn_i(resetn_i),
                .ID_bram_selected_rd_i(ID_bram_selected),
                .s_Data_out_i(s_Data_out),
                .Data_out(Data_out0)   
            );
            
        end

        // else if (MODE == 1) begin
        //     //port 0
        //     wire            [NUMBER_BRAM-1:0]                    s_wr0_in;
        //     wire            [NUMBER_BRAM*ADDR_WIDTH-1:0]         s_addr_wr0;  // address local for each BRAM
        //     wire            [NUMBER_BRAM*ADDR_WIDTH-1:0]         s_addr_rd0;  // address local for each BRAM
        //     wire            [NUMBER_BRAM*DATA_WIDTH-1:0]         s_Data_in0;
        //     wire            [NUMBER_BRAM*DATA_WIDTH-1:0]         s_Data_out0;
        //     wire            [NUMBER_BRAM-1:0]                    ID_bram_selected0;

        //     //port 1
        //     wire            [NUMBER_BRAM-1:0]                    s_wr1_in;
        //     wire            [NUMBER_BRAM*ADDR_WIDTH-1:0]         s_addr_wr1;  // address local for each BRAM
        //     wire            [NUMBER_BRAM*ADDR_WIDTH-1:0]         s_addr_rd1;  // address local for each BRAM
        //     wire            [NUMBER_BRAM*DATA_WIDTH-1:0]         s_Data_in1;
        //     wire            [NUMBER_BRAM*DATA_WIDTH-1:0]         s_Data_out1;
        //     wire            [NUMBER_BRAM-1:0]                    ID_bram_selected1;



        //     decoder_frame_buffer#(
        //         .ADDR_WIDTH(ADDR_WIDTH),
        //         .DATA_WIDTH(DATA_WIDTH),
        //         .NUMBER_BRAM(NUMBER_BRAM),
        //         .DEPTH_SIZE(DEPTH_SIZE)
        //     )decoder_frame_buffer0_uut(
        //         //input mem
        //         .wr_i(wr0_i),
        //         .addr_wr(addr_wr0),
        //         .addr_rd(addr_rd0),
        //         .Data_in(Data_in0),
        //     //decoder port for each bram
        //         .s_wr_in_o(s_wr0_in), 
        //         .s_addr_wr_o(s_addr_wr0),
        //         .s_addr_rd_o(s_addr_rd0),
        //         .s_Data_in_o(s_Data_in0),
        //         .ID_bram_selected_rd_o(ID_bram_selected0)
        //     );

        //     decoder_frame_buffer#(
        //         .ADDR_WIDTH(ADDR_WIDTH),
        //         .DATA_WIDTH(DATA_WIDTH),
        //         .NUMBER_BRAM(NUMBER_BRAM),
        //         .DEPTH_SIZE(DEPTH_SIZE)
        //     )decoder_frame_buffer1_uut(
        //         //input mem
        //         .wr_i(wr1_i),
        //         .addr_wr(addr_wr1),
        //         .addr_rd(addr_rd1),
        //         .Data_in(Data_in1),
        //     //decoder port for each bram
        //         .s_wr_in_o(s_wr1_in), 
        //         .s_addr_wr_o(s_addr_wr1),
        //         .s_addr_rd_o(s_addr_rd1),
        //         .s_Data_in_o(s_Data_in1),
        //         .ID_bram_selected_rd_o(ID_bram_selected1)   
        //     );

        //     // gen block ram
        //     genvar bram_count;
        //     // generate
        //         for (bram_count = 0; bram_count < NUMBER_BRAM; bram_count = bram_count + 1) begin : g_bram
        //             wire [ADDR_WIDTH-1:0]  aw0 = s_addr_wr0 [((ADDR_WIDTH*bram_count)+ADDR_WIDTH-1) -: ADDR_WIDTH];
        //             wire [ADDR_WIDTH-1:0]  ar0 = s_addr_rd0 [((ADDR_WIDTH*bram_count)+ADDR_WIDTH-1) -: ADDR_WIDTH];
        //             wire [DATA_WIDTH-1:0]  din0 = s_Data_in0 [((DATA_WIDTH*bram_count)+DATA_WIDTH-1) -: DATA_WIDTH];
        //             wire                   we0  = s_wr0_in[bram_count];

        //             wire [ADDR_WIDTH-1:0]  aw1 = s_addr_wr1 [((ADDR_WIDTH*bram_count)+ADDR_WIDTH-1) -: ADDR_WIDTH];
        //             wire [ADDR_WIDTH-1:0]  ar1 = s_addr_rd1 [((ADDR_WIDTH*bram_count)+ADDR_WIDTH-1) -: ADDR_WIDTH];
        //             wire [DATA_WIDTH-1:0]  din1 = s_Data_in1 [((DATA_WIDTH*bram_count)+DATA_WIDTH-1) -: DATA_WIDTH];
        //             wire                   we1  = s_wr1_in[bram_count];

        //             block_ram_frame_buffer1 #(
        //                 .ADDR_WIDTH (ADDR_WIDTH),   // có thể giảm xuống $clog2(DEPTH_SIZE) nếu muốn gọn địa chỉ local
        //                 .DATA_WIDTH (DATA_WIDTH),
        //                 .DEPTH_SIZE (DEPTH_SIZE)
        //             ) u_bram (
        //                 .clk_i    (clk_i),
        //                 .wr_i0     (we0),
        //                 .addr_wr0  (aw0   - (DEPTH_SIZE*bram_count)),
        //                 .addr_rd0  (ar0   - (DEPTH_SIZE*bram_count)),
        //                 .Data_in0  (din0),
        //                 .Data_out0 (s_Data_out0[((DATA_WIDTH*bram_count)+DATA_WIDTH-1) -: DATA_WIDTH]),

        //                 .wr_i1     (we1),
        //                 .addr_wr1  (aw1   - (DEPTH_SIZE*bram_count)),
        //                 .addr_rd1  (ar1   - (DEPTH_SIZE*bram_count)),
        //                 .Data_in1  (din1),
        //                 .Data_out1 (s_Data_out1[((DATA_WIDTH*bram_count)+DATA_WIDTH-1) -: DATA_WIDTH])
        //             );
        //         end
        //     // endgenerate

        //     encoder_frame_buffer#(
        //         .DATA_WIDTH(DATA_WIDTH),
        //         .NUMBER_BRAM(NUMBER_BRAM)
        //     )encoder_frame_buffer0_uut(
        //         .clk_i(clk_i),
        //         .resetn_i(resetn_i),
        //         .ID_bram_selected_rd_i(ID_bram_selected0),
        //         .s_Data_out_i(s_Data_out0),
        //         .Data_out(Data_out0)   
        //     );

        //     encoder_frame_buffer#(
        //         .DATA_WIDTH(DATA_WIDTH),
        //         .NUMBER_BRAM(NUMBER_BRAM)
        //     )encoder_frame_buffer1_uut(
        //         .clk_i(clk_i),
        //         .resetn_i(resetn_i),
        //         .ID_bram_selected_rd_i(ID_bram_selected1),
        //         .s_Data_out_i(s_Data_out1),
        //         .Data_out(Data_out1)   
        //     );


        // end


        else if (MODE == 2) begin
            //port 0
            wire            [NUMBER_BRAM-1:0]                    s_wr0_in;
            wire            [NUMBER_BRAM*ADDR_WIDTH-1:0]         s_addr_wr0;  // address local for each BRAM
            wire            [NUMBER_BRAM*ADDR_WIDTH-1:0]         s_addr_rd0;  // address local for each BRAM
            wire            [NUMBER_BRAM*DATA_WIDTH-1:0]         s_Data_in0;
            wire            [NUMBER_BRAM*DATA_WIDTH-1:0]         s_Data_out0;
            wire            [NUMBER_BRAM-1:0]                    ID_bram_selected0;

            //port 1
            wire            [NUMBER_BRAM*ADDR_WIDTH-1:0]         s_addr_rd1;  // address local for each BRAM
            wire            [NUMBER_BRAM*DATA_WIDTH-1:0]         s_Data_out1;
            wire            [NUMBER_BRAM-1:0]                    ID_bram_selected1;



            decoder_frame_buffer#(
                .ADDR_WIDTH(ADDR_WIDTH),
                .DATA_WIDTH(DATA_WIDTH),
                .NUMBER_BRAM(NUMBER_BRAM),
                .DEPTH_SIZE(DEPTH_SIZE)
            )decoder_frame_buffer0_uut(
                //input mem
                .wr_i(wr0_i),
                .addr_wr(addr_wr0),
                .addr_rd(addr_rd0),
                .Data_in(Data_in0),
            //decoder port for each bram
                .s_wr_in_o(s_wr0_in), 
                .s_addr_wr_o(s_addr_wr0),
                .s_addr_rd_o(s_addr_rd0),
                .s_Data_in_o(s_Data_in0),
                .ID_bram_selected_rd_o(ID_bram_selected0)
            );

            single_rd_ecoder_frame_buffer#(
                .ADDR_WIDTH(ADDR_WIDTH),
                .DATA_WIDTH(DATA_WIDTH),
                .NUMBER_BRAM(NUMBER_BRAM),
                .DEPTH_SIZE(DEPTH_SIZE)
            )decoder_frame_buffer1_uut(
                //input mem
                .addr_rd(addr_rd1),
            //decoder port for each bram
                .s_addr_rd_o(s_addr_rd1),
                .ID_bram_selected_rd_o(ID_bram_selected1)   
            );

            // gen block ram
            genvar bram_count;
            // generate
                for (bram_count = 0; bram_count < NUMBER_BRAM; bram_count = bram_count + 1) begin : g_bram
                    wire [ADDR_WIDTH-1:0]  aw0 = s_addr_wr0 [((ADDR_WIDTH*bram_count)+ADDR_WIDTH-1) -: ADDR_WIDTH];
                    wire [ADDR_WIDTH-1:0]  ar0 = s_addr_rd0 [((ADDR_WIDTH*bram_count)+ADDR_WIDTH-1) -: ADDR_WIDTH];
                    wire [DATA_WIDTH-1:0]  din0 = s_Data_in0 [((DATA_WIDTH*bram_count)+DATA_WIDTH-1) -: DATA_WIDTH];
                    wire                   we0  = s_wr0_in[bram_count];  
                    wire [ADDR_WIDTH-1:0]  ar1 = s_addr_rd1 [((ADDR_WIDTH*bram_count)+ADDR_WIDTH-1) -: ADDR_WIDTH];

                    block_ram_frame_buffer2 #(
                        .ADDR_WIDTH (ADDR_WIDTH),   // có thể giảm xuống $clog2(DEPTH_SIZE) nếu muốn gọn địa chỉ local
                        .DATA_WIDTH (DATA_WIDTH),
                        .DEPTH_SIZE (DEPTH_SIZE),
                        .TEST_PATTERN_NUM (bram_count),
                        .ENB_TEST_PATTERN(ENB_TEST_PATTERN)
                    ) u_bram (
                        .clk_i    (clk_i),
                        .wr_i0     (we0),
                        .addr_wr0  (aw0   - (DEPTH_SIZE*bram_count)),
                        .addr_rd0  (ar0   - (DEPTH_SIZE*bram_count)),
                        .Data_in0  (din0),
                        .Data_out0 (s_Data_out0[((DATA_WIDTH*bram_count)+DATA_WIDTH-1) -: DATA_WIDTH]),
                        .addr_rd1  (ar1   - (DEPTH_SIZE*bram_count)),
                        .Data_out1 (s_Data_out1[((DATA_WIDTH*bram_count)+DATA_WIDTH-1) -: DATA_WIDTH])
                    );
                end
            // endgenerate

            encoder_frame_buffer#(
                .DATA_WIDTH(DATA_WIDTH),
                .NUMBER_BRAM(NUMBER_BRAM)
            )encoder_frame_buffer0_uut(
                .clk_i(clk_i),
                .resetn_i(resetn_i),
                .ID_bram_selected_rd_i(ID_bram_selected0),
                .s_Data_out_i(s_Data_out0),
                .Data_out(Data_out0)   
            );

            encoder_frame_buffer#(
                .DATA_WIDTH(DATA_WIDTH),
                .NUMBER_BRAM(NUMBER_BRAM)
            )encoder_frame_buffer1_uut(
                .clk_i(clk_i),
                .resetn_i(resetn_i),
                .ID_bram_selected_rd_i(ID_bram_selected1),
                .s_Data_out_i(s_Data_out1),
                .Data_out(Data_out1)   
            );


        end
    endgenerate

    





endmodule


module decoder_frame_buffer#(
    parameter ADDR_WIDTH    = 32,
    parameter DATA_WIDTH    = 16, //WORD_SIZE
    parameter NUMBER_BRAM   = 16,
    parameter DEPTH_SIZE    = 262144 // size bram = (WORD_SIZE * DEPTH_SIZE)/8 (Byte) 


)(
    //input mem
    input                               wr_i,

    input           [ADDR_WIDTH-1:0]    addr_wr,
    input           [ADDR_WIDTH-1:0]    addr_rd,
    input           [DATA_WIDTH-1:0]    Data_in,


    //decoder port for each bram
    output          [NUMBER_BRAM-1:0]                             s_wr_in_o, 
    output          [NUMBER_BRAM*ADDR_WIDTH-1:0]                  s_addr_wr_o,
    output          [NUMBER_BRAM*ADDR_WIDTH-1:0]                  s_addr_rd_o,
    output          [NUMBER_BRAM*DATA_WIDTH-1:0]                  s_Data_in_o,
    output          [NUMBER_BRAM-1:0]                             ID_bram_selected_rd_o

);  

    wire [NUMBER_BRAM-1:0] ID_bram_selected_wr;
    wire [NUMBER_BRAM-1:0] ID_bram_selected_rd;
    

    genvar  bram_count;
    //decoder addr_wr   
    generate
        for (bram_count = 0; bram_count < NUMBER_BRAM; bram_count = bram_count + 1) begin
            assign ID_bram_selected_wr[bram_count] = ((addr_wr >= DEPTH_SIZE*bram_count) && (addr_wr < (DEPTH_SIZE*bram_count) + DEPTH_SIZE));
        end
    endgenerate

    //decoder addr_rd   
    generate
        for (bram_count = 0; bram_count < NUMBER_BRAM; bram_count = bram_count + 1) begin
            assign ID_bram_selected_rd[bram_count] = ((addr_rd >= DEPTH_SIZE*bram_count) && (addr_rd < (DEPTH_SIZE*bram_count) + DEPTH_SIZE));
        end
    endgenerate


    //connect awaddr_wr master to bram
    generate
        for (bram_count = 0; bram_count < NUMBER_BRAM; bram_count = bram_count + 1) begin
            assign s_addr_wr_o[((ADDR_WIDTH*bram_count)+ADDR_WIDTH-1) -: ADDR_WIDTH] = (ID_bram_selected_wr[bram_count]) ?  addr_wr : 0;
        end
    endgenerate

    generate
        for (bram_count = 0; bram_count < NUMBER_BRAM; bram_count = bram_count + 1) begin
            assign s_addr_rd_o[((ADDR_WIDTH*bram_count)+ADDR_WIDTH-1) -: ADDR_WIDTH] = (ID_bram_selected_rd[bram_count]) ?  addr_rd : 0;
        end
    endgenerate

    generate
        for (bram_count = 0; bram_count < NUMBER_BRAM; bram_count = bram_count + 1) begin
            assign s_wr_in_o[bram_count] = (ID_bram_selected_wr[bram_count]) ?  wr_i : 0;
        end
    endgenerate

    generate
        for (bram_count = 0; bram_count < NUMBER_BRAM; bram_count = bram_count + 1) begin
            assign s_Data_in_o[((DATA_WIDTH*bram_count)+DATA_WIDTH-1) -: DATA_WIDTH] = (ID_bram_selected_wr[bram_count]) ? Data_in : 0;
        end
    endgenerate



    assign ID_bram_selected_rd_o = ID_bram_selected_rd;


endmodule



// single port read
module single_rd_ecoder_frame_buffer#(
    parameter ADDR_WIDTH    = 32,
    parameter DATA_WIDTH    = 16, //WORD_SIZE
    parameter NUMBER_BRAM   = 16,
    parameter DEPTH_SIZE    = 1024 // size bram = (WORD_SIZE * DEPTH_SIZE)/8 (Byte) 


)(
    //input mem
    input           [ADDR_WIDTH-1:0]                              addr_rd,


    //decoder port for each bram
    output          [NUMBER_BRAM*ADDR_WIDTH-1:0]                  s_addr_rd_o,
    output          [NUMBER_BRAM-1:0]                             ID_bram_selected_rd_o

);  

    wire [NUMBER_BRAM-1:0] ID_bram_selected_rd;
    

    genvar  bram_count;

    //decoder addr_rd   
    generate
        for (bram_count = 0; bram_count < NUMBER_BRAM; bram_count = bram_count + 1) begin
            assign ID_bram_selected_rd[bram_count] = ((addr_rd >= DEPTH_SIZE*bram_count) && (addr_rd < (DEPTH_SIZE*bram_count) + DEPTH_SIZE));
        end
    endgenerate


    //connect awaddr_rd master to bram
    generate
        for (bram_count = 0; bram_count < NUMBER_BRAM; bram_count = bram_count + 1) begin
            assign s_addr_rd_o[((ADDR_WIDTH*bram_count)+ADDR_WIDTH-1) -: ADDR_WIDTH] = (ID_bram_selected_rd[bram_count]) ?  addr_rd : 0;
        end
    endgenerate

    assign ID_bram_selected_rd_o = ID_bram_selected_rd;


endmodule


module encoder_frame_buffer#(
    parameter DATA_WIDTH    = 16, //WORD_SIZE
    parameter NUMBER_BRAM   = 3
)(  
    input                                       clk_i,
    input                                       resetn_i,
    input       [NUMBER_BRAM-1:0]               ID_bram_selected_rd_i,
    input       [NUMBER_BRAM*DATA_WIDTH-1:0]    s_Data_out_i,
    output  reg [DATA_WIDTH-1:0]                Data_out    

);  

    reg         [NUMBER_BRAM-1:0]  ID_bram_next, ID_bram_reg;

    always @(posedge clk_i) begin
        if (~resetn_i) begin
            ID_bram_reg <= 0;
        end
        else begin
            ID_bram_reg <= ID_bram_next;
        end
        
    end

    integer i;
    always @(*) begin
        ID_bram_next = ID_bram_selected_rd_i;
        Data_out  = {DATA_WIDTH{1'b0}};
        for (i = 0; i < NUMBER_BRAM; i = i + 1) begin  
            Data_out = Data_out | ({DATA_WIDTH{/* ID_bram_selected_rd_i */ID_bram_reg[i]}} & s_Data_out_i[((DATA_WIDTH*i) + DATA_WIDTH -1) -: DATA_WIDTH]);
        end
    end

endmodule


module block_ram_frame_buffer0#(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter DEPTH_SIZE = 1024 // size bram = (WORD_SIZE * DEPTH_SIZE)/8 (Byte) 
)(
    input                               clk_i,

    input                               wr_i,

    input           [ADDR_WIDTH-1:0]    addr_wr,
    input           [ADDR_WIDTH-1:0]    addr_rd,

    input           [DATA_WIDTH-1:0]    Data_in,
    output  reg     [DATA_WIDTH-1:0]    Data_out

    );

    reg [DATA_WIDTH-1:0] mem [0:DEPTH_SIZE-1]; //524_288 byte

    always @(posedge clk_i) begin
        if(wr_i) begin
            mem[addr_wr] <= Data_in;
        end
        Data_out <= mem[addr_rd];
    end

endmodule


// module block_ram_frame_buffer1#(
//     parameter ADDR_WIDTH = 32,
//     parameter DATA_WIDTH = 32,
//     parameter DEPTH_SIZE = 1024 // size bram = (WORD_SIZE * DEPTH_SIZE)/8 (Byte) 
// )(
//     input                               clk_i,

//     input                               wr_i0,
//     input                               wr_i1,

//     input           [ADDR_WIDTH-1:0]    addr_wr0,
//     input           [ADDR_WIDTH-1:0]    addr_wr1,
//     input           [ADDR_WIDTH-1:0]    addr_rd0,
//     input           [ADDR_WIDTH-1:0]    addr_rd1,

//     input           [DATA_WIDTH-1:0]    Data_in0,
//     input           [DATA_WIDTH-1:0]    Data_in1,
//     output  reg     [DATA_WIDTH-1:0]    Data_out0,
//     output  reg     [DATA_WIDTH-1:0]    Data_out1

//     );

//     reg [DATA_WIDTH-1:0] mem [0:DEPTH_SIZE-1]; //524_288 byte


//     // port 0
//     always @(posedge clk_i) begin
//         if(wr_i0) begin
//             mem[addr_wr0] <= Data_in0;
//         end
//         Data_out0 <= mem[addr_rd0];
        
//     end


//     // port 1
//     always @(posedge clk_i) begin
//         if(wr_i1) begin
//             mem[addr_wr1] <= Data_in1;
//         end
//         Data_out1 <= mem[addr_rd1];
//     end

// endmodule


module block_ram_frame_buffer2#(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter DEPTH_SIZE = 1024, // size bram = (WORD_SIZE * DEPTH_SIZE)/8 (Byte) 
    parameter TEST_PATTERN_NUM = 0,
    parameter ENB_TEST_PATTERN = 1
)(
    input                               clk_i,

    input                               wr_i0,

    input           [ADDR_WIDTH-1:0]    addr_wr0,

    input           [ADDR_WIDTH-1:0]    addr_rd0,
    input           [ADDR_WIDTH-1:0]    addr_rd1,

    input           [DATA_WIDTH-1:0]    Data_in0,

    output  reg     [DATA_WIDTH-1:0]    Data_out0,
    output  reg     [DATA_WIDTH-1:0]    Data_out1

    );

    reg [DATA_WIDTH-1:0] mem [0:DEPTH_SIZE-1]; //524_288 byte

    generate
        if (ENB_TEST_PATTERN == 1) begin
            if (TEST_PATTERN_NUM <= 35) begin
                initial begin
                    // $readmemh("black_mem.hex", mem); // For hexadecimal data
                    // $readmemh("white_mem.hex", mem);
                    $readmemh("soft_purple.hex", mem);
                end
            end
            else begin
                initial begin
                    $readmemh("white_mem.hex", mem); // For hexadecimal data
                end
            end
        end
        
    endgenerate
    


    // port 0
    always @(posedge clk_i) begin
        if(wr_i0) begin
            mem[addr_wr0] <= Data_in0;
        end
        Data_out0 <= mem[addr_rd0];
        
    end


    // port 1
    always @(posedge clk_i) begin
        Data_out1 <= mem[addr_rd1];
    end

endmodule



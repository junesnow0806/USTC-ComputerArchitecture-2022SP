`timescale 1ns / 1ps
//  功能说明
    // MEM\WB的写回寄存器内容
    // 为了数据同步，Data Extension和Data Cache集成在其�?
// 输入
    // clk               时钟信号
    // wb_select         选择写回寄存器的数据：如果为0，写回ALU计算结果，如果为1，写回Memory读取的内�?
    // load_type         load指令类型
    // write_en          Data Cache写使�?
    // debug_write_en    Data Cache debug写使�?
    // addr              Data Cache的写地址，也是ALU的计算结�?
    // debug_addr        Data Cache的debug写地�?
    // in_data           Data Cache的写入数�?
    // debug_in_data     Data Cache的debug写入数据
    // bubbleW           WB阶段的bubble信号
    // flushW            WB阶段的flush信号
// 输出
    // debug_out_data    Data Cache的debug读出数据
    // data_WB           传给下一流水段的写回寄存器内�?
// 实验要求  
    /* TODO:
     * 在本模块内部用cache替换原来的DataCache
     * 增加输出端口, 使得发生cache缺失时可以停顿流水线 -> hazard unit
     * 计算缺失�?, 本模块内进行
     */

module WB_Data_WB(
    input wire clk, rst, bubbleW, flushW,
    input wire wb_select,
    input wire [2:0] load_type,
    input  [3:0] write_en, debug_write_en,
    input  [31:0] addr,
    input  [31:0] debug_addr,
    input  [31:0] in_data, debug_in_data,
    output wire [31:0] debug_out_data,
    output wire [31:0] data_WB,
    output wire miss
    );

    wire [31:0] data_raw;
    wire [31:0] data_WB_raw;

    /*
    DataCache DataCache1(
        .clk(clk),
        .write_en(write_en << addr[1:0]),
        .debug_write_en(debug_write_en),
        .addr(addr[31:2]),
        .debug_addr(debug_addr[31:2]),
        .in_data(in_data << (8 * addr[1:0])),
        .debug_in_data(debug_in_data),
        .out_data(data_raw),
        .debug_out_data(debug_out_data)
    );
    */

    wire rd_req, wr_req;
    assign rd_req = wb_select;
    assign wr_req = (write_en == 4'b1111) ? 1'b1 : 1'b0; // write_en==4'b1111时是sw指令
    cache Datacache1(
        .clk(clk),
        .rst(rst),
        .addr(addr),
        .rd_req(rd_req), // wb_select�?1时�?�择读取Memory的内容写回寄存器
        .wr_req(wr_req),
        .wr_data(in_data),
        .miss(miss),
        .rd_data(data_raw)
    );

    reg [31:0] miss_count, access_count;
    wire access;
    assign access = (rd_req | wr_req);

    // miss信号取边�?
    reg miss1, miss2;
    wire miss_edge;
    always @(posedge clk) begin
        if (!flushW) begin
            miss1 <= miss;
            miss2 <= miss1;
        end else begin
            miss1 <= 1'b0;
            miss2 <= 1'b0;
        end
    end
    assign miss_edge = miss1 & miss2;

    // access信号取边�?
    reg access1, access2;
    wire access_edge;
    always @(posedge clk) begin
        if (!flushW) begin
            access1 <= access;
            access2 <= access1;
        end else begin
            access1 <= 1'b0;
            access2 <= 1'b0;
        end
    end
    assign access_edge = access1 & access2;

    // 计算miss_count和access_count
    always @(posedge clk) begin
        if (!flushW) begin
            if (miss_edge) begin
                miss_count <= miss_count + 1;
            end
        end
    end
    always @(posedge clk) begin
        if (!flushW) begin
            if (access_edge) begin
                access_count <= access_count + 1;
            end
        end
    end

    // 计算缺失�?
    reg [31:0] miss_rate;
    always @(*) begin
        if (access_count == 0) begin
            miss_rate = 0;
        end else begin
            miss_rate = miss_count / access_count;
        end
    end

    // Add flush and bubble support
    // if chip not enabled, output output last read result
    // else if chip clear, output 0
    // else output values from cache

    reg bubble_ff = 1'b0;
    reg flush_ff = 1'b0;
    reg wb_select_old = 0;
    reg [31:0] data_WB_old = 32'b0;
    reg [31:0] addr_old;
    reg [2:0] load_type_old;

    DataExtend DataExtend1(
        .data(data_raw),
        .addr(addr_old[1:0]),
        .load_type(load_type_old),
        .dealt_data(data_WB_raw)
    );

    always@(posedge clk)
    begin
        bubble_ff <= bubbleW;
        flush_ff <= flushW;
        data_WB_old <= data_WB;
        addr_old <= addr;
        wb_select_old <= wb_select;
        load_type_old <= load_type;
    end

    assign data_WB = bubble_ff ? data_WB_old :
                                 (flush_ff ? 32'b0 : 
                                             (wb_select_old ? data_WB_raw :
                                                          addr_old));

endmodule
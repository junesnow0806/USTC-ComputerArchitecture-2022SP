`timescale 1ns / 1ps
// 实验要求
    // 补全模块（阶段三）

/* CSR寄存器堆, 位于EX段
 * 读和写CSR寄存器
 */
module CSR_Regfile(
    input wire clk,
    input wire rst,
    input wire CSR_write_en,
    input wire [11:0] CSR_write_addr,
    input wire [11:0] CSR_read_addr,
    input wire [31:0] CSR_data_write,
    output wire [31:0] CSR_data_read
    );
    
    // TODO: Complete this module

    /* FIXME: Write your code here... */
    parameter XLEN = 32; // 系统的操作位数, RV32I即32位
    parameter CSR_NUM = 2 ** 12; // CSR寄存器的个数
    reg [XLEN-1:0] CSR_file[CSR_NUM-1:0];
    integer i;

    // 初始化CSR寄存器堆
    initial 
    begin
        for (i = 0; i < CSR_NUM; i = i + 1)
            CSR_file[i] = 32'b0;   
    end

    always @ (posedge clk, posedge rst)
    begin
        if (rst)
        begin
            for (i = 1; i < CSR_NUM; i = i + 1)
                CSR_file[i] <= 32'b0;
        end
        else if (CSR_write_en)
            CSR_file[CSR_write_addr] <= CSR_data_write;
    end

    // read data
    assign CSR_data_read = CSR_file[CSR_read_addr];
endmodule

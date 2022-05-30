`timescale 1ns / 1ps
// 实验要求
    // 补全模块（阶段三）

/* ID-EX的段间寄存器
 * 需要从ID段向EX段传递的值或信号有：
 * CSR_addr_ID: 在ID段译码得到的要访问的CSR寄存器地址
 * CSR_zimm_ID: 在ID段读取的rs1寄存器值或rs1字段生成的zimm立即数
 * CSR_zimm_or_reg_ID: 标记rs1字段是寄存器地址还是立即数, 为0时表示是寄存器, 为1时表示是立即数
 * CSR_write_en_ID: CSR寄存器写使能
 */
module CSR_EX(
    input wire clk, bubbleE, flushE,
    input wire [11:0] CSR_addr_ID,
    input wire [31:0] CSR_zimm_ID,
    input wire CSR_zimm_or_reg_ID,
    input wire CSR_write_en_ID,
    output reg [11:0] CSR_addr_EX,
    output reg [31:0] CSR_zimm_EX,
    output reg CSR_zimm_or_reg_EX,
    output reg CSR_write_en_EX
    );

    // TODO: Complete this module

    /* FIXME: Write your code here... */
    initial begin
        CSR_addr_EX = 0;
        CSR_write_en_EX = 0;
        CSR_zimm_EX = 0;
        CSR_zimm_or_reg_EX = 0;
    end

    always @ (posedge clk) 
    begin
        if (!bubbleE) 
        begin
            if (flushE)
            begin
                CSR_addr_EX <= 0;
                CSR_write_en_EX <= 0;
                CSR_zimm_EX <= 0;
                CSR_zimm_or_reg_EX <= 0;
            end
            else
            begin
                CSR_addr_EX <= CSR_addr_ID;
                CSR_write_en_EX <= CSR_write_en_ID;
                CSR_zimm_EX <= CSR_zimm_ID;
                CSR_zimm_or_reg_EX <= CSR_zimm_or_reg_ID;
            end
        end
    end

endmodule

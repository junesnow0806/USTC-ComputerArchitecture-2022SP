`timescale 1ns / 1ps
//  功能说明
    //  算数运算和逻辑运算功能部件
// 输入
    // op1               第一个操作数
    // op2               第二个操作数
    // ALU_func          运算类型
// 输出
    // ALU_out           运算结果
// 实验要求
    // 补全模块

`include "Parameters.v"   
module ALU(
    input wire [31:0] op1,
    input wire [31:0] op2,
    input wire [3:0] ALU_func,
    output reg [31:0] ALU_out
    );

    // TODO: Complete this module

    // FIXME:wire signed [31:0] op1_signed, op2_signed2;
    wire signed [31:0] op1_signed, op2_signed;
    assign op1_signed = op1;
    assign op2_signed = op2;
    always @ (*)
    begin
        case(ALU_func)
            `ADD: ALU_out = op1 + op2;
            `SLL: ALU_out = op1 << op2[4:0];
            `SLTU: ALU_out = (op1 < op2) ? 32'd1 : 32'd0;
            `LUI: ALU_out = op2;

            /* FIXME: Write your code here... */
            `SUB: ALU_out = op1 - op2;
            `AND: ALU_out = op1 & op2;
            `OR: ALU_out = op1 | op2;
            `XOR: ALU_out = op1 ^ op2;
            `SRL: ALU_out = op1 >> op2[4:0];
            `SRA: ALU_out = op1_signed >>> op2[4:0];
            `SLT: ALU_out = (op1_signed < op2_signed) ? 32'd1 : 32'd0;
            `OP1: ALU_out = op1; // CSRRW和CSRRWI需要直接使用rs1寄存器的值
            `OP2: ALU_out = op2;
            `NAND: ALU_out = ~op1 & op2; // !!!注意这里不是真正的"与非"运算, 而是对操作数1取反后再跟操作数2相与, 因为要实现CSRRC指令要用到

            default: ALU_out = 32'b0;
        endcase
    end
endmodule


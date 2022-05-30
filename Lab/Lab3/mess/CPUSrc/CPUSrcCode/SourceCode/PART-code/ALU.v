`timescale 1ns / 1ps
//  功能说明
    //  算数运算和�?�辑运算功能部件
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

    wire signed [31:0] op1_s, op2_s;
    assign op1_s = op1;
    assign op2_s = op2;

    always @ (*)
    begin
        case(ALU_func)
            `ADD: ALU_out = op1 + op2;
            `SLL: ALU_out = op1 << op2[4:0];
            `SLTU: ALU_out = (op1 < op2) ? 32'd1 : 32'd0;
            `LUI: ALU_out = op2;

            /* FIXME: Write your code here... */
            `SRL: ALU_out = op1 >> op2[4:0];
            `SRA: ALU_out = op1_s >>> op2[4:0];
            `SUB: ALU_out = op1 + ~op2 + 1;
            `XOR: ALU_out = op1 ^ op2;
            `OR: ALU_out = op1 | op2;
            `AND: ALU_out = op1 & op2;
            `SLT: ALU_out = (op1_s < op2_s) ? 32'd1 : 32'd0;
            `OP1: ALU_out = op1;
            `OP2: ALU_out = op2;
            `NAND: ALU_out = ~op1 & op2; //??
            default: ALU_out = 32'b0;
        endcase
    end
endmodule


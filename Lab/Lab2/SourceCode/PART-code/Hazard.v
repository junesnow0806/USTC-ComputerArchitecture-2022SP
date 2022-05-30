`timescale 1ns / 1ps
//  功能说明
    //  识别流水线中的数据冲突，控制数据转发，和flush、bubble信号
// 输入
    // rst               CPU的rst信号
    // reg1_srcD         ID阶段的源reg1地址
    // reg2_srcD         ID阶段的源reg2地址
    // reg1_srcE         EX阶段的源reg1地址
    // reg2_srcE         EX阶段的源reg2地址
    // reg_dstE          EX阶段的目的reg地址
    // reg_dstM          MEM阶段的目的reg地址
    // reg_dstW          WB阶段的目的reg地址
    // br                是否branch
    // jalr              是否jalr
    // jal               是否jal
    // wb_select         写回寄存器的值的来源（Cache内容或者ALU计算结果）
    // reg_write_en_MEM  MEM阶段的寄存器写使能信号
    // reg_write_en_WB   WB阶段的寄存器写使能信号
// 输出
    // flushF            IF阶段的flush信号
    // bubbleF           IF阶段的bubble信号
    // flushD            ID阶段的flush信号
    // bubbleD           ID阶段的bubble信号
    // flushE            EX阶段的flush信号
    // bubbleE           EX阶段的bubble信号
    // flushM            MEM阶段的flush信号
    // bubbleM           MEM阶段的bubble信号
    // flushW            WB阶段的flush信号
    // bubbleW           WB阶段的bubble信号
    // op1_sel           00 is reg1, 01 is mem stage forwarding, 01 is wb stage forwarding
    // op2_sel           00 is reg2, 01 is mem stage forwarding, 01 is wb stage forwarding

// 实验要求
    // 补全模块

`include "Parameters.v"   
module HarzardUnit(
    input wire rst,
    input wire [4:0] reg1_srcD, reg2_srcD, reg1_srcE, reg2_srcE, reg_dstE, reg_dstM, reg_dstW,
    input wire br, jalr, jal,
    input wire wb_select,
    input wire reg_write_en_MEM,
    input wire reg_write_en_WB,
    output reg flushF, bubbleF, flushD, bubbleD, flushE, bubbleE, flushM, bubbleM, flushW, bubbleW,
    output reg [1:0] op1_sel, op2_sel
    );

    // TODO: Complete this module


    // generate op1_sel
    always @ (*)
    begin 
        if (reg1_srcE == reg_dstM && reg_write_en_MEM == 1 && reg1_srcE != 0)
        begin
            // mem to ex forwarding, mem forwarding first
            op1_sel = 2'b01;
        end
        else if (reg1_srcE == reg_dstW && reg_write_en_WB == 1 && reg1_srcE != 0)
        begin
            // wb to ex forwarding
            op1_sel = 2'b10;
        end
        else 
        begin
            op1_sel = 2'b00;
        end
    end

    // generate bubbleM and flushM
    always @ (*)
    begin
        if (rst)
        begin
            bubbleM = 0;
            flushM = 1;
        end
        else 
        begin
            bubbleM = 0;
            flushM = 0;
        end
    end

    /* FIXME: Write your code here... */

    // generate op2_sel
    always @ (*)
    begin 
        if (reg2_srcE == reg_dstM && reg_write_en_MEM == 1 && reg2_srcE != 0)
        begin
            // mem to ex forwarding, mem forwarding first
            op2_sel = 2'b01;
        end
        else if (reg2_srcE == reg_dstW && reg_write_en_WB == 1 && reg2_srcE != 0)
        begin
            // wb to ex forwarding
            op2_sel = 2'b10;
        end
        else 
        begin
            op2_sel = 2'b00;
        end
    end

    // generate bubbleW and flushW
    always @ (*)
    begin
        if (rst)
        begin
            bubbleW = 0;
            flushW = 1;
        end
        else 
        begin
            bubbleW = 0;
            flushW = 0;
        end
    end

    // generate bubbleF, flushF, bubbleD, flushD. bubbleE, and flushE
    // 需要注意br, jalr和jal的执行有优先级br == jalr > jal
    always @ (*)
    begin
        if (rst)
        begin
            bubbleF = 0;
            flushF = 1;
            bubbleD = 0;
            flushD = 1;
            bubbleE = 0;
            flushE = 1;
        end
        else if (wb_select == 1 && (reg_dstE == reg1_srcD || reg_dstE == reg2_srcD))
        begin
            // load-use数据相关, 在load指令的EX阶段和use指令的ID阶段检测到
            // 需要停顿IF前和IF-ID的段间寄存器, 清空ID-EX的段间寄存器
            bubbleF = 1;
            flushF = 0;
            bubbleD = 1;
            flushD = 0;
            bubbleE = 0;
            flushE = 1;
        end
        else if (br)
        begin
            // br指令在EX段确定跳转
            // 需要清空ID-EX和IF-ID的段间寄存器
            // 由于NPC MUX会选择正确的下一条指令, 所以IF PC不需要停顿也不需要清空
            bubbleF = 0;
            flushF = 0;
            bubbleD = 0;
            flushD = 1;
            bubbleE = 0;
            flushE = 1;
        end
        else if (jalr)
        begin
            // jalr指令在EX段由ALU计算出目标地址
            // 需要清空ID-EX和IF-ID的段间寄存器
            bubbleF = 0;
            flushF = 0;
            bubbleD = 0;
            flushD = 1;
            bubbleE = 0;
            flushE = 1;
        end
        else if (jal)
        begin
            // jal在ID段就确定目标地址
            bubbleF = 0;
            flushF = 0;
            bubbleD = 0;
            flushD = 1;
            bubbleE = 0;
            flushE = 0;
        end
        else
        begin
            bubbleF = 0;
            flushF = 0;
            bubbleD = 0;
            flushD = 0;
            bubbleE = 0;
            flushE = 0;
        end
    end

endmodule
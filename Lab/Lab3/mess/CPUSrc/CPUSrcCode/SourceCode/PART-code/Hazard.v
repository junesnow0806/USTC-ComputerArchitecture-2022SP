`timescale 1ns / 1ps
//  ����˵��
    //  ʶ����ˮ���е����ݳ�ͻ����������ת������flush��bubble�ź�
// ����
    // rst               CPU��rst�ź�
    // reg1_srcD         ID�׶ε�Դreg1��ַ
    // reg2_srcD         ID�׶ε�Դreg2��ַ
    // reg1_srcE         EX�׶ε�Դreg1��ַ
    // reg2_srcE         EX�׶ε�Դreg2��ַ
    // reg_dstE          EX�׶ε�Ŀ��reg��ַ
    // reg_dstM          MEM�׶ε�Ŀ��reg��ַ
    // reg_dstW          WB�׶ε�Ŀ��reg��ַ
    // br                �Ƿ�branch
    // jalr              �Ƿ�jalr
    // jal               �Ƿ�jal
    // wb_select         д�ؼĴ�����ֵ����Դ��Cache���ݻ���ALU��������
    // reg_write_en_MEM  MEM�׶εļĴ���дʹ���ź�
    // reg_write_en_WB   WB�׶εļĴ���дʹ���ź�
    // TODO: miss        DataCache������ȱʧ�ź�
// ���
    // flushF            IF�׶ε�flush�ź�
    // bubbleF           IF�׶ε�bubble�ź�
    // flushD            ID�׶ε�flush�ź�
    // bubbleD           ID�׶ε�bubble�ź�
    // flushE            EX�׶ε�flush�ź�
    // bubbleE           EX�׶ε�bubble�ź�
    // flushM            MEM�׶ε�flush�ź�
    // bubbleM           MEM�׶ε�bubble�ź�
    // flushW            WB�׶ε�flush�ź�
    // bubbleW           WB�׶ε�bubble�ź�
    // op1_sel           00 is reg1, 01 is mem stage forwarding, 01 is wb stage forwarding
    // op2_sel           00 is reg2, 01 is mem stage forwarding, 01 is wb stage forwarding

// ʵ��Ҫ��
    // ��ȫģ��

`include "Parameters.v"   
module HarzardUnit(
    input wire rst,

    input wire miss,

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
        else if (miss)
        begin
            bubbleW = 1;
            flushW = 0;
        end
        else 
        begin
            bubbleW = 0;
            flushW = 0;
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
        else if (miss)
        begin
            bubbleM = 1;
            flushM = 0;
        end
        else 
        begin
            bubbleM = 0;
            flushM = 0;
        end
    end

    // generate bubbleF, flushF, bubbleD, flushD. bubbleE, and flushE
    // ��Ҫע��br, jalr��jal��ִ�������ȼ�br == jalr > jal
    // ����miss����
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
        else if (miss) // ����DataCacheȱʧ��ͣ����ˮ��
        begin
            bubbleF = 1;
            flushF = 0;
            bubbleD = 1;
            flushD = 0;
            bubbleE = 1;
            flushE = 0;
        end
        else if (wb_select == 1 && (reg_dstE == reg1_srcD || reg_dstE == reg2_srcD))
        begin
            // load-use�������, ��loadָ���EX�׶κ�useָ���ID�׶μ�⵽
            // ��Ҫͣ��IFǰ��IF-ID�Ķμ�Ĵ���, ���ID-EX�Ķμ�Ĵ���
            bubbleF = 1;
            flushF = 0;
            bubbleD = 1;
            flushD = 0;
            bubbleE = 0;
            flushE = 1;
        end
        else if (br)
        begin
            // brָ����EX��ȷ����ת
            // ��Ҫ���ID-EX��IF-ID�Ķμ�Ĵ���
            // ����NPC MUX��ѡ����ȷ����һ��ָ��, ����IF PC����Ҫͣ��Ҳ����Ҫ���
            bubbleF = 0;
            flushF = 0;
            bubbleD = 0;
            flushD = 1;
            bubbleE = 0;
            flushE = 1;
        end
        else if (jalr)
        begin
            // jalrָ����EX����ALU�����Ŀ���ַ
            // ��Ҫ���ID-EX��IF-ID�Ķμ�Ĵ���
            bubbleF = 0;
            flushF = 0;
            bubbleD = 0;
            flushD = 1;
            bubbleE = 0;
            flushE = 1;
        end
        else if (jal)
        begin
            // jal��ID�ξ�ȷ��Ŀ���ַ
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
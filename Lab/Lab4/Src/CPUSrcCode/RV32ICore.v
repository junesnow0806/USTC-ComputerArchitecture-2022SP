`timescale 1ns / 1ps
//功能说明
    // RV32I Core的顶层模块
//实验要求  
    // TODO: 增加动态分支预测模块

module RV32ICore(
    input wire CPU_CLK,
    input wire CPU_RST,
    input wire [31:0] CPU_Debug_DataCache_A2,
    input wire [31:0] CPU_Debug_DataCache_WD2,
    input wire [3:0] CPU_Debug_DataCache_WE2,
    output wire [31:0] CPU_Debug_DataCache_RD2,
    input wire [31:0] CPU_Debug_InstCache_A2,
    input wire [31:0] CPU_Debug_InstCache_WD2,
    input wire [ 3:0] CPU_Debug_InstCache_WE2,
    output wire [31:0] CPU_Debug_InstCache_RD2
    );
    
	//wire values definitions
    wire bubbleF, flushF, bubbleD, flushD, bubbleE, flushE, bubbleM, flushM, bubbleW, flushW;
    wire [31:0] jal_target, br_target;
    wire jal, br;
    wire jalr_ID, jalr_EX;
    wire [31:0] NPC, PC_IF, PC_4, PC_ID, PC_EX;
    wire [31:0] inst_ID;
    wire reg_write_en_ID, reg_write_en_EX, reg_write_en_MEM, reg_write_en_WB;
    wire [4:0] reg1_src_EX;
    wire [4:0] reg2_src_EX;
    wire [4:0] reg_dest_EX, reg_dest_MEM, reg_dest_WB;
    wire [31:0] data_WB;
    wire [31:0] reg1, reg1_EX;
    wire [31:0] reg2, reg2_EX, reg2_MEM;
    wire [31:0] reg_or_imm;
    wire op1_src, op2_src;
    wire [3:0] ALU_func_ID, ALU_func_EX;
    wire [2:0] br_type_ID, br_type_EX;
    wire load_npc_ID, load_npc_EX;
    wire wb_select_ID, wb_select_EX, wb_select_MEM;
    wire [2:0] load_type_ID, load_type_EX, load_type_MEM;
    wire [3:0] cache_write_en_ID, cache_write_en_EX, cache_write_en_MEM;
    wire [2:0] imm_type;
    wire [31:0] imm;
    wire [31:0] ALU_op1, ALU_op2, ALU_out;
    wire [31:0] result, result_MEM;
    wire [1:0] op1_sel, op2_sel;

    wire [31:0] imm_EX;
    wire [31:0] reg1_forwarding, reg2_forwarding;
    wire op1_src_EX, op2_src_EX;
    
    // CSR Instruction 
    wire [31:0] CSR_data_read, CSR_data_EX;
    wire [11:0] CSR_addr, CSR_addr_EX;
    wire CSR_write_en, CSR_write_en_EX;
    wire [31:0] CSR_zimm, CSR_zimm_EX;
    wire CSR_zimm_or_reg, CSR_zimm_or_reg_EX;
    
    // (CSR) EX_stage wires
    wire [31:0] npc_or_aluout;
    wire [31:0] ALU_op1_csr, ALU_op1_reg_or_imm;
    wire [31:0] ALU_op2_reg_or_imm;

    


    // Adder to compute PC + 4
    assign PC_4 = PC_IF + 4;


    // Adder to compute PC_ID + Imm - 4
    assign jal_target = PC_ID + imm - 4;
    // MUX for reg1 forwarding
    assign reg1_forwarding =  (op1_sel == 2'b00) ? reg1_EX : 
                                         ((op1_sel == 2'b01) ? result_MEM : data_WB);

    // MUX for reg2 forwarding
    assign reg2_forwarding = (op2_sel == 2'b00) ? reg2_EX : 
                                             ((op2_sel == 2'b01) ? result_MEM : data_WB);
                                             
    
    // MUX for ALU op1                                         
    assign ALU_op1_reg_or_imm = (op1_src_EX == 1'b0) ? reg1_forwarding : (PC_EX - 4);
    // ALUop1 CSR Mux
    assign ALU_op1_csr = (CSR_zimm_or_reg_EX == 0) ? reg1_forwarding : CSR_zimm_EX;
    assign ALU_op1 = (CSR_write_en_EX == 0) ? ALU_op1_reg_or_imm : ALU_op1_csr;
    
    // MUX for ALU op2                                         
    assign ALU_op2_reg_or_imm = (op2_src_EX == 1'b0) ? reg2_forwarding : imm_EX;
    // ALUop2 CSR Mux
    assign ALU_op2 = (CSR_write_en_EX == 0) ? ALU_op2_reg_or_imm : CSR_data_EX;
    


    // MUX for result (ALU or PC_EX)
    assign npc_or_aluout = load_npc_EX ? PC_EX : ALU_out;
    // EX CSR mux
    assign result = (CSR_write_en_EX == 0) ? npc_or_aluout : CSR_data_EX;
    
    
    // CSR
    assign CSR_zimm = {27'b0, inst_ID[19:15]}; // zimm zero extension
    assign CSR_addr = {inst_ID[31:20]};

    // cache miss
    wire miss;
    
    // Branch Prediction
    wire is_branch;
    reg is_taken_if_ID, is_taken_if_EX;
    wire is_taken_ex;
    wire [31:0] set_target_addr;
    wire [31:0] PCE;   // 注意PC_EX是已经加上4的
    wire predict_taken_or_not;
    wire [31:0] predict_target;
    wire [1:0] predict_error_type;
    wire br_npc;
    reg br_npc_reg;
    wire [31:0] PC_plus4;
    reg [31:0] PC_plus4_reg;
    wire [31:0] br_target_npc;
    reg [31:0] br_target_npc_reg;
    assign PCE = PC_EX - 4;
    assign is_branch = (br_type_EX == `NOBRANCH) ? 1'b0 : 1'b1;
    assign is_taken_ex = br;
    // assign is_taken_if = br_npc;
    assign br_npc = br_npc_reg;
    assign PC_plus4 = PC_plus4_reg;
    assign br_target_npc = br_target_npc_reg;
    always @(posedge CPU_CLK, posedge CPU_RST) begin
        if (CPU_RST) begin
            is_taken_if_ID <= 0;
            is_taken_if_EX <= 0;
        end else begin
            is_taken_if_ID <= br_npc;
            is_taken_if_EX <= is_taken_if_ID; 
        end
    end

    //Module connections
    // ---------------------------------------------
    // PC-Generator
    // ---------------------------------------------

    // 原本的br是由EX段的Branch模块生成的
    // 加入动态分支预测后需要根据Branch Prediction Unit的输出来确定
    wire jal_npc, jalr_npc;
    assign jal_npc = (predict_error_type[1] == 1'b0) ? jal : 1'b0;
    assign jalr_npc = (predict_error_type[1] == 1'b0) ? jalr_EX : 1'b0;
    always @(*) begin
        if (predict_error_type[1] == 1'b0) begin
            // 现在进行到EX段的branch指令没有预测错误
            // 将使用动态分支预测的结果
            // br_npc_reg = predict_taken_or_not; Wrong!
            
            if (jal_npc == 1'b1) begin
                // ID段有一条jal指令
                br_npc_reg = 1'b0;
            end else begin
                br_npc_reg = predict_taken_or_not;
            end
            
            br_target_npc_reg = predict_target;
            PC_plus4_reg = PC_4;
        end else if (predict_error_type == 2'b11) begin
            // 预测跳转但实际上不跳转
            // 还需要强制使NPC MUX选择PCE+4作为下一条指令地址
            // 需要另jal和jalr信号清零
            br_npc_reg = 1'b0;
            br_target_npc_reg = 32'b0;
            PC_plus4_reg = PC_EX;
        end else if (predict_error_type == 2'b10) begin
            // 预测不跳转但实际上需要跳转
            br_npc_reg = 1'b1;
            br_target_npc_reg = br_target; // 当前EX段的branch目标地址
            PC_plus4_reg = PC_4;
        end else begin
            br_npc_reg = 1'b0;
            br_target_npc_reg = 32'b0;
            PC_plus4_reg = PC_4;
        end
    end
    // 现在考虑当br_npc和jal_npc同时为1的情况
    // 如果br_npc来自EX段, 则应br_npc优先
    // 如果br_npc来自IF段, 则应jal_npc优先, 此时jal_npc来自ID段, 先于br_npc
    // 后一种情况需要修改的是br_npc, 另其为0


    NPC_Generator NPC_Generator1(
        // .PC(PC_4),
        .PC(PC_plus4),
        .jal_target(jal_target),
        .jalr_target(ALU_out),
        // .br_target(br_target),
        // .br_target(predict_target),
        .br_target(br_target_npc),
        // .jal(jal),
        .jal(jal_npc),
        // .jalr(jalr_EX),
        .jalr(jalr_npc),
        // .br(br),
        .br(br_npc),
        .NPC(NPC)
    );


    PC_IF PC_IF1(
        .clk(CPU_CLK),
        .bubbleF(bubbleF),
        .flushF(flushF),
        .NPC(NPC),
        .PC(PC_IF)
    );



    // ---------------------------------------------
    // IF stage
    // ---------------------------------------------

    PC_ID PC_ID1(
        .clk(CPU_CLK),
        .bubbleD(bubbleD),
        .flushD(flushD),
        .PC_IF(PC_4),
        .PC_ID(PC_ID)
    );


    IR_ID IR_ID1(
        .clk(CPU_CLK),
        .bubbleD(bubbleD),
        .flushD(flushD),
        .write_en(|CPU_Debug_InstCache_WE2),
        .addr(PC_IF[31:2]),
        .debug_addr(CPU_Debug_InstCache_A2[31:2]),
        .debug_input(CPU_Debug_InstCache_WD2),
        .inst_ID(inst_ID),
        .debug_data(CPU_Debug_InstCache_RD2)
    );



    // ---------------------------------------------
    // ID stage
    // ---------------------------------------------

    CSR_EX CSR_EX1(
        .clk(CPU_CLK),
        .bubbleE(bubbleE),
        .flushE(flushE),
        .CSR_addr_ID(CSR_addr),
        .CSR_zimm_ID(CSR_zimm),
        .CSR_zimm_or_reg_ID(CSR_zimm_or_reg),
        .CSR_write_en_ID(CSR_write_en),
        .CSR_addr_EX(CSR_addr_EX),
        .CSR_zimm_EX(CSR_zimm_EX),
        .CSR_zimm_or_reg_EX(CSR_zimm_or_reg_EX),
        .CSR_write_en_EX(CSR_write_en_EX)
    );
    
    
    RegisterFile RegisterFile1(
        .clk(CPU_CLK),
        .rst(CPU_RST),
        .write_en(reg_write_en_WB),
        .addr1(inst_ID[19:15]),
        .addr2(inst_ID[24:20]),
        .wb_addr(reg_dest_WB),
        .wb_data(data_WB),
        .reg1(reg1),
        .reg2(reg2)
    );


    ControllerDecoder ControllerDecoder1(
        .inst(inst_ID),
        .jal(jal),
        .jalr(jalr_ID),
        .op1_src(op1_src),
        .op2_src(op2_src),
        .ALU_func(ALU_func_ID),
        .br_type(br_type_ID),
        .load_npc(load_npc_ID),
        .wb_select(wb_select_ID),
        .load_type(load_type_ID),
        .reg_write_en(reg_write_en_ID),
        .cache_write_en(cache_write_en_ID),
        .imm_type(imm_type),
        .CSR_write_en(CSR_write_en),
        .CSR_zimm_or_reg(CSR_zimm_or_reg)
    );

    ImmExtend ImmExtend1(
        .inst(inst_ID[31:7]),
        .imm_type(imm_type),
        .imm(imm)
    );


    PC_EX PC_EX1(
        .clk(CPU_CLK),
        .bubbleE(bubbleE),
        .flushE(flushE),
        .PC_ID(PC_ID),
        .PC_EX(PC_EX)
    );

    BR_Target_EX BR_Target_EX1(
        .clk(CPU_CLK),
        .bubbleE(bubbleE),
        .flushE(flushE),
        .address(jal_target),
        .address_EX(br_target)
    );

    Op1_EX Op1_EX1(
        .clk(CPU_CLK),
        .bubbleE(bubbleE),
        .flushE(flushE),
        .reg1(reg1),
        .reg1_EX(reg1_EX)
    );
    
    Imm_EX Imm_EX1(
        .clk(CPU_CLK),
        .bubbleE(bubbleE),
        .flushE(flushE),
        .imm_in(imm),
        .imm_out(imm_EX)
    );

    Reg2_EX Reg2_EX1(
        .clk(CPU_CLK),
        .bubbleE(bubbleE),
        .flushE(flushE),
        .reg2(reg2),
        .reg2_EX(reg2_EX)
    );

    Addr_EX Addr_EX1(
        .clk(CPU_CLK),
        .bubbleE(bubbleE),
        .flushE(flushE),
        .reg1_src_ID(inst_ID[19:15]),
        .reg2_src_ID(inst_ID[24:20]),
        .reg_dest_ID(inst_ID[11:7]),
        .reg1_src_EX(reg1_src_EX),
        .reg2_src_EX(reg2_src_EX),
        .reg_dest_EX(reg_dest_EX)
    );



    Ctrl_EX Ctrl_EX1(
        .clk(CPU_CLK),
        .bubbleE(bubbleE),
        .flushE(flushE),
        .jalr_ID(jalr_ID),
        .ALU_func_ID(ALU_func_ID),
        .br_type_ID(br_type_ID),
        .load_npc_ID(load_npc_ID),
        .wb_select_ID(wb_select_ID),
        .load_type_ID(load_type_ID),
        .reg_write_en_ID(reg_write_en_ID),
        .cache_write_en_ID(cache_write_en_ID),
        .jalr_EX(jalr_EX),
        .ALU_func_EX(ALU_func_EX),
        .br_type_EX(br_type_EX),
        .load_npc_EX(load_npc_EX),
        .wb_select_EX(wb_select_EX),
        .load_type_EX(load_type_EX),
        .reg_write_en_EX(reg_write_en_EX),
        .cache_write_en_EX(cache_write_en_EX),
        .op1_src_ID(op1_src),
        .op2_src_ID(op2_src),
        .op1_src_EX(op1_src_EX),
        .op2_src_EX(op2_src_EX)
    );


    // ---------------------------------------------
    // EX stage
    // ---------------------------------------------
    CSR_Regfile CSR_Regfile(
        .clk(CPU_CLK),
        .rst(CPU_RST),
        .CSR_write_en(CSR_write_en_EX),
        .CSR_write_addr(CSR_addr_EX),
        .CSR_read_addr(CSR_addr_EX),
        .CSR_data_write(ALU_out),
        .CSR_data_read(CSR_data_EX)
    );
    
    ALU ALU1(
        .op1(ALU_op1),
        .op2(ALU_op2),
        .ALU_func(ALU_func_EX),
        .ALU_out(ALU_out)
    );

    BranchDecision BranchDecision1(
        .reg1(reg1_forwarding),
        .reg2(reg2_forwarding),
        .br_type(br_type_EX),
        .br(br)
    );
    
    

    

    Result_MEM Result_MEM1(
        .clk(CPU_CLK),
        .bubbleM(bubbleM),
        .flushM(flushM),
        .result(result),
        .result_MEM(result_MEM)
    );

    Reg2_MEM Reg2_MEM1(
        .clk(CPU_CLK),
        .bubbleM(bubbleM),
        .flushM(flushM),
        .reg2_EX(reg2_forwarding),
        .reg2_MEM(reg2_MEM)
    );

    Addr_MEM Addr_MEM1(
        .clk(CPU_CLK),
        .bubbleM(bubbleM),
        .flushM(flushM),
        .reg_dest_EX(reg_dest_EX),
        .reg_dest_MEM(reg_dest_MEM)
    );



    Ctrl_MEM Ctrl_MEM1(
        .clk(CPU_CLK),
        .bubbleM(bubbleM),
        .flushM(flushM),
        .wb_select_EX(wb_select_EX),
        .load_type_EX(load_type_EX),
        .reg_write_en_EX(reg_write_en_EX),
        .cache_write_en_EX(cache_write_en_EX),
        .wb_select_MEM(wb_select_MEM),
        .load_type_MEM(load_type_MEM),
        .reg_write_en_MEM(reg_write_en_MEM),
        .cache_write_en_MEM(cache_write_en_MEM)
    );



    // ---------------------------------------------
    // MEM stage
    // ---------------------------------------------


    WB_Data_WB WB_Data_WB1(
        .clk(CPU_CLK),
        .rst(CPU_RST),
        .bubbleW(bubbleW),
        .flushW(flushW),
        .wb_select(wb_select_MEM),
        .load_type(load_type_MEM),
        .write_en(cache_write_en_MEM),
        .debug_write_en(CPU_Debug_DataCache_WE2),
        .addr(result_MEM),
        .debug_addr(CPU_Debug_DataCache_A2),
        .in_data(reg2_MEM),
        .debug_in_data(CPU_Debug_DataCache_WD2),
        .debug_out_data(CPU_Debug_DataCache_RD2),
        .data_WB(data_WB),
        .miss(miss)
    );


    Addr_WB Addr_WB1(
        .clk(CPU_CLK),
        .bubbleW(bubbleW),
        .flushW(flushW),
        .reg_dest_MEM(reg_dest_MEM),
        .reg_dest_WB(reg_dest_WB)
    );

    Ctrl_WB Ctrl_WB1(
        .clk(CPU_CLK),
        .bubbleW(bubbleW),
        .flushW(flushW),
        .reg_write_en_MEM(reg_write_en_MEM),
        .reg_write_en_WB(reg_write_en_WB)
    );




    // ---------------------------------------------
    // WB stage
    // ---------------------------------------------



    // ---------------------------------------------
    // Harzard Unit
    // ---------------------------------------------
    HarzardUnit HarzardUnit1(
        .rst(CPU_RST),
        .miss(miss),
        .predict_error_type(predict_error_type),
        .reg1_srcD(inst_ID[19:15]),
        .reg2_srcD(inst_ID[24:20]),
        .reg1_srcE(reg1_src_EX),
        .reg2_srcE(reg2_src_EX),
        .reg_dstE(reg_dest_EX),
        .reg_dstM(reg_dest_MEM),
        .reg_dstW(reg_dest_WB),
        .br(br),
        .jalr(jalr_EX),
        .jal(jal),
        .wb_select(wb_select_EX),
        .reg_write_en_MEM(reg_write_en_MEM),
        .reg_write_en_WB(reg_write_en_WB),
        .flushF(flushF),
        .bubbleF(bubbleF),
        .flushD(flushD),
        .bubbleD(bubbleD),
        .flushE(flushE),
        .bubbleE(bubbleE),
        .flushM(flushM),
        .bubbleM(bubbleM),
        .flushW(flushW),
        .bubbleW(bubbleW),
        .op1_sel(op1_sel),
        .op2_sel(op2_sel)
    );  



    // ---------------------------------------------
    // Branch Prediction Unit
    // ---------------------------------------------
    BranchPrediction BPU (
        .clk(CPU_CLK),
        .rst(CPU_RST),
        .PCF(PC_IF),
        .PCE(PCE),
        .is_branch(is_branch),
        .is_taken_ex(is_taken_ex),
        .is_taken_if(is_taken_if_EX),
        .set_target_addr(br_target),
        .predict_taken_or_not(predict_taken_or_not),
        .predict_target(predict_target),
        .predict_error_type(predict_error_type)
    );
    	         
endmodule
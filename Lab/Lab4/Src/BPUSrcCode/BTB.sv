module BTB #(
    parameter BTB_INDEX_LEN = 12
)(
    input clk, 
    input rst,
    input [31:0] PCF,
    input [31:0] PCE,
    input is_branch,                // EX阶段判断是否是一条branch指令
    input is_taken_ex,              // EX阶段判断是否跳转结果
    input is_taken_if,              // 该branch指令在IF阶段的预测, 在EX段传进来
    input [31:0] set_target_addr,   // EX阶段计算出来的branch目标地址
    output btb_hit,                 // BTB是否命中
    output btb_hit_without_valid,
    output [1:0] predict_error_type,      // 预测错误类型
    output [31:0] predict_target
);

// 预测错误类型
localparam Taken_NTaken = 2'b11;    // 预测跳转但实际不跳转
localparam NTaken_Taken = 2'b10;    // 预测不跳转但实际跳转
localparam NTaken_NTaken = 2'b01;
localparam Taken_Taken = 2'b00;

localparam HIGH_ADDRESS_LEN = 32 - BTB_INDEX_LEN;
localparam BTB_SIZE = 1 << BTB_INDEX_LEN;

reg valid [BTB_SIZE];
reg [31:0] target_addr_buffer [BTB_SIZE]; // 缓存分支指令的目标指令地址
reg [HIGH_ADDRESS_LEN-1:0] high_addr_buffer [BTB_SIZE]; // 缓存分支指令的高位地址


wire [BTB_INDEX_LEN-1:0] buffer_index_IF;
wire [BTB_INDEX_LEN-1:0] buffer_index_EX;
assign buffer_index_IF = PCF[BTB_INDEX_LEN-1:0];
assign buffer_index_EX = PCE[BTB_INDEX_LEN-1:0];

reg [1:0] predict_error_type_reg;
assign btb_hit = (PCF[31:BTB_INDEX_LEN] == high_addr_buffer[buffer_index_IF]) & valid[buffer_index_IF];
assign btb_hit_without_valid = (PCF[31:BTB_INDEX_LEN] == high_addr_buffer[buffer_index_IF]);
assign predict_target = target_addr_buffer[buffer_index_IF];
assign predict_error_type = predict_error_type_reg;

// 修改BTB内的表项
always @(posedge clk, posedge rst) begin
    if (rst) begin
        for (integer i = 0; i < BTB_SIZE; i = i + 1) begin
            valid[i] <= 1'b0;
            target_addr_buffer[i] <= 32'b0;
            high_addr_buffer[i] <= {HIGH_ADDRESS_LEN{1'b0}};
        end
    end else if (is_branch) begin // 当前EX段是一条branch指令
        if (is_taken_ex & is_taken_if) begin
            // EX阶段判断需要跳转, 在IF段时也跳转了
            valid[buffer_index_EX] <= 1'b1;
            high_addr_buffer[buffer_index_EX] <= PCE[31:BTB_INDEX_LEN];
            target_addr_buffer[buffer_index_EX] <= set_target_addr;
        end else if (is_taken_ex & !is_taken_if) begin
            // EX阶段判断需要跳转, 但是在IF段时没有跳转, 预测错误
            valid[buffer_index_EX] <= 1'b1;
            high_addr_buffer[buffer_index_EX] <= PCE[31:BTB_INDEX_LEN];
            target_addr_buffer[buffer_index_EX] <= set_target_addr;
        end else if (!is_taken_ex & is_taken_if) begin
            // EX阶段判断不跳转, 但是在IF段时跳转了, 预测错误
            valid[buffer_index_EX] <= 1'b0;
        end else if (!is_taken_ex & !is_taken_if) begin
            // EX阶段判断不跳转, 实际在IF段时也确实没有跳转
            // 需要将该项valid置成0
            valid[buffer_index_EX] <= 1'b0;
        end
    end
end

// 预测出错信息应一发现就马上更新, 而不是等posedge!!
always @(*) begin
    if (is_branch) begin // 当前EX段是一条branch指令
        if (is_taken_ex & is_taken_if) begin
            // EX阶段判断需要跳转, 在IF段时也跳转了
            predict_error_type_reg = Taken_Taken;
        end else if (is_taken_ex & !is_taken_if) begin
            // EX阶段判断需要跳转, 但是在IF段时没有跳转, 预测错误
            predict_error_type_reg = NTaken_Taken;
        end else if (!is_taken_ex & is_taken_if) begin
            // EX阶段判断不跳转, 但是在IF段时跳转了, 预测错误
            predict_error_type_reg = Taken_NTaken;
        end else if (!is_taken_ex & !is_taken_if) begin
            // EX阶段判断不跳转, 实际在IF段时也确实没有跳转
            predict_error_type_reg = NTaken_NTaken;
        end
    end else begin
        predict_error_type_reg = 0;
    end
end

endmodule
/* 2-bit BHT */
module BHT #(
    parameter BHT_INDEX_LEN = 12
)(
    input clk, 
    input rst,
    input [31:0] PCF,
    input [31:0] PCE,
    input is_branch,                // EX阶段判断是否是一条branch指令
    input is_taken_ex,              // EX阶段判断是否跳转结果
    output predict_taken_or_not     // 根据传入的IF段PC输出预测是否跳转
);

localparam BHT_SIZE = 1 << BHT_INDEX_LEN;

// status类型
localparam STRONGLY_TAKEN = 2'b11;
localparam WEAKLY_TAKEN = 2'b10;
localparam WEAKLY_NOT_TAKEN = 2'b01;
localparam STRONGLY_NOT_TAKEN = 2'b00;

reg [1:0] status [BHT_SIZE];
initial begin
    for (integer i = 0; i < BHT_SIZE; i = i + 1) begin
        status[i] = 2'b00;
    end
end

wire [BHT_INDEX_LEN-1:0] status_index_IF;
wire [BHT_INDEX_LEN-1:0] status_index_EX;
assign status_index_IF = PCF[BHT_INDEX_LEN-1:0];
assign status_index_EX = PCE[BHT_INDEX_LEN-1:0];

assign predict_taken_or_not = status[status_index_IF][1];

always @(posedge clk, posedge rst) begin
    if (rst) begin
        for (integer i = 0; i < BHT_INDEX_LEN; i = i + 1) begin
            status[i] <= STRONGLY_NOT_TAKEN;
        end
    end else if (is_branch) begin
        if (is_taken_ex) begin
            if (status[status_index_EX] != STRONGLY_TAKEN) begin
                status[status_index_EX] <= status[status_index_EX] + 1;
            end
        end else begin
            if (status[status_index_EX] != STRONGLY_NOT_TAKEN) begin
                status[status_index_EX] <= status[status_index_EX] - 1;
            end
        end
    end
end

endmodule
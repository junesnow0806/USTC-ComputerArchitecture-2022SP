module BranchPrediction #(
    parameter INDEX_LEN = 12
)(
    input clk,
    input rst,
    input [31:0] PCF,
    input [31:0] PCE,
    input is_branch,
    input is_taken_ex,
    input is_taken_if,
    input [31:0] set_target_addr,
    output predict_taken_or_not,
    output [31:0] predict_target,
    output [1:0] predict_error_type
);

localparam INCLUDE_BHT = 1'b0; // �?1时表示使用BHT, 否则仅使用BTB

wire btb_hit, btb_hit_without_valid;
wire predict_taken_or_not_bht;
assign predict_taken_or_not = (INCLUDE_BHT == 1'b1) ? (btb_hit_without_valid & predict_taken_or_not_bht) : btb_hit;

BTB #(
    .BTB_INDEX_LEN(INDEX_LEN)
) BTB1 (
    .clk(clk),
    .rst(rst),
    .PCF(PCF),
    .PCE(PCE),
    .is_branch(is_branch),
    .is_taken_ex(is_taken_ex),
    .is_taken_if(is_taken_if),
    .set_target_addr(set_target_addr),
    .btb_hit(btb_hit),
    .btb_hit_without_valid(btb_hit_without_valid),
    .predict_error_type(predict_error_type),
    .predict_target(predict_target)
);

BHT #(
    .BHT_INDEX_LEN(INDEX_LEN)
) BHT1 (
    .clk(clk),
    .rst(rst),
    .PCF(PCF), 
    .PCE(PCE),
    .is_branch(is_branch),
    .is_taken_ex(is_taken_ex),
    .predict_taken_or_not(predict_taken_or_not_bht)
);

// 增加统计分支指令数目, 预测正确次数和错误次数的电路
reg [31:0] br_count;
initial br_count = 32'b0;
always @(posedge clk) begin
    if (is_branch) begin
        br_count <= br_count + 1;
    end
end

reg [31:0] wrong_count;
initial wrong_count = 32'b0;
always @(posedge clk) begin
    if (predict_error_type[1] == 1'b1) begin
        wrong_count <= wrong_count + 1;
    end
end

wire [31:0] correct_count;
assign correct_count = br_count - wrong_count;


endmodule
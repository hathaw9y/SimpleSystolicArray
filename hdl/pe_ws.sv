module pe_ws #(
    parameter int ACT_W    = 8,   // activation 비트폭
    parameter int WEIGHT_W = 8,   // weight 비트폭
    parameter int ACC_W    = 32   // 누산기 비트폭 (오버플로우 방지)
) (
    input  logic                       aclk_i,          // 클락
    input  logic                       aresetn_i,       // 액티브 로우 리셋
    input  logic                       act_valid_i,     // activation 유효 신호
    input  logic                       weight_valid_i,  // weight 유효 신호
    input  logic                       acc_valid_i,     // acc 유효 신호
    input  logic signed [   ACT_W-1:0] act_i,           // 왼쪽 PE에서 전달된 activation
    input  logic signed [WEIGHT_W-1:0] weight_i,        // 위쪽 PE에서 전달된 weight
    input  logic signed [   ACC_W-1:0] acc_i,           // 위쪽 PE에서 전달된 부분합
    output logic                       act_valid_o,     // 오른쪽 PE로 유효 신호 전달
    output logic                       acc_valid_o,     // 아래쪽 PE로 유효 신호 전달
    output logic signed [   ACT_W-1:0] act_o,           // 오른쪽 PE로 activation 전달
    output logic signed [WEIGHT_W-1:0] weight_o,        // 아래쪽 PE로 weight 전달
    output logic signed [   ACC_W-1:0] acc_o            // 누산 결과 출력
);
  logic signed [WEIGHT_W-1:0] weight_reg;  // weight 레지스터

  always_ff @(posedge aclk_i) begin
    if (!aresetn_i) begin
      act_valid_o <= 0;
      acc_valid_o <= 0;
      act_o       <= 0;
      weight_o    <= 0;
      acc_o       <= 0;
      weight_reg  <= 0;
    end else begin
      if (weight_valid_i) begin
        weight_reg <= weight_i;  // weight는 위쪽 PE에서 1클락 지연 저장
      end
      // 신호 및 데이터를 인접 PE로 1클락 지연 전파
      act_valid_o <= act_valid_i;
      acc_valid_o <= act_valid_i && acc_valid_i;  // 양쪽 valid일 때만 acc 유효
      act_o       <= act_i;
      weight_o    <= weight_i;
      if (act_valid_i && acc_valid_i) begin
        acc_o <= $signed(act_i) * $signed(weight_reg) + $signed(acc_i);  // 누산
      end else begin
        acc_o <= acc_i;
      end
    end
  end
endmodule

module pipeline_reg #(
    parameter int DATA_W = 8,  // 데이터 비트폭
    parameter int DEPTH  = 0   // 지연 클락 수 (행 번호와 동일)
) (
    input  logic              aclk_i,
    input  logic              aresetn_i,
    input  logic [DATA_W-1:0] data_i,
    output logic [DATA_W-1:0] data_o
);

  if (DEPTH == 0) begin : g_no_delay
    assign data_o = data_i;
  end else begin : g_delay
    logic [DATA_W-1:0] shift_reg[DEPTH];

    always_ff @(posedge aclk_i) begin
      if (!aresetn_i) begin
        for (int i = 0; i < DEPTH; i++) shift_reg[i] <= '0;
      end else begin
        shift_reg[0] <= data_i;
        for (int i = 1; i < DEPTH; i++) shift_reg[i] <= shift_reg[i-1];
      end
    end

    assign data_o = shift_reg[DEPTH-1];
  end

endmodule

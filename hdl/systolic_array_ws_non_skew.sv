module systolic_array_ws_non_skew #(
    parameter int ROWS     = 16,
    parameter int COLS     = 16,
    parameter int ACT_W    = 8,
    parameter int WEIGHT_W = 8,
    parameter int ACC_W    = 32
) (
    input  logic                       aclk_i,
    input  logic                       aresetn_i,
    input  logic                       weight_valid_i,
    input  logic                       act_valid_i   [ROWS],
    input  logic signed [   ACT_W-1:0] act_i         [ROWS],
    input  logic signed [WEIGHT_W-1:0] weight_i      [COLS],
    output logic                       acc_valid_o   [COLS],
    output logic signed [   ACC_W-1:0] acc_o         [COLS]
);

  // PE 간 연결 wire
  logic signed [   ACT_W-1:0] act_wire      [  ROWS][COLS+1];
  logic signed [WEIGHT_W-1:0] weight_wire   [ROWS+1][  COLS];
  logic signed [   ACC_W-1:0] acc_wire      [ROWS+1][  COLS];
  logic                       act_valid_wire[  ROWS][COLS+1];
  logic                       acc_valid_wire[ROWS+1][  COLS];

  // =========================================================
  // 입력 연결
  // =========================================================
  genvar i;
  generate
    for (i = 0; i < ROWS; i++) begin : g_input_act
      assign act_wire[i][0]       = act_i[i];
      assign act_valid_wire[i][0] = act_valid_i[i];
    end

    for (i = 0; i < COLS; i++) begin : g_input_acc
      assign acc_wire[0][i]       = '0;
      assign acc_valid_wire[0][i] = 1'b1;

      assign weight_wire[0][i]    = weight_i[i];
    end
  endgenerate

  // =========================================================
  // 출력 연결
  // =========================================================
  generate
    for (i = 0; i < COLS; i++) begin : g_output
      assign acc_valid_o[i] = acc_valid_wire[ROWS][i];
      assign acc_o[i]       = acc_wire[ROWS][i];
    end
  endgenerate

  // =========================================================
  // PE 배열
  // =========================================================
  genvar row, col;
  generate
    for (row = 0; row < ROWS; row++) begin : g_row
      for (col = 0; col < COLS; col++) begin : g_col
        pe_ws #(
            .ACT_W   (ACT_W),
            .WEIGHT_W(WEIGHT_W),
            .ACC_W   (ACC_W)
        ) u_pe (
            .aclk_i        (aclk_i),
            .aresetn_i     (aresetn_i),
            .act_valid_i   (act_valid_wire[row][col]),
            .weight_valid_i(weight_valid_i),
            .acc_valid_i   (acc_valid_wire[row][col]),
            .act_i         (act_wire[row][col]),
            .weight_i      (weight_wire[row][col]),
            .acc_i         (acc_wire[row][col]),
            .act_valid_o   (act_valid_wire[row][col+1]),
            .acc_valid_o   (acc_valid_wire[row+1][col]),
            .act_o         (act_wire[row][col+1]),
            .weight_o      (weight_wire[row+1][col]),
            .acc_o         (acc_wire[row+1][col])
        );
      end
    end
  endgenerate

endmodule

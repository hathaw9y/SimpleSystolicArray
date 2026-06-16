module systolic_array_os_non_skew #(
    parameter int ROWS     = 16,
    parameter int COLS     = 16,
    parameter int ACT_W    = 8,
    parameter int WEIGHT_W = 8,
    parameter int ACC_W    = 32
) (
    input  logic                       aclk_i,
    input  logic                       aresetn_i,
    input  logic signed [   ACT_W-1:0] act_i         [ROWS],
    input  logic signed [WEIGHT_W-1:0] weight_i      [COLS],
    input  logic                       act_valid_i   [ROWS],
    input  logic                       weight_valid_i[COLS],
    input  logic                       acc_clear_i,
    output logic signed [   ACC_W-1:0] acc_o         [ROWS][COLS]
);

  // PE 간 연결 wire
  logic signed [   ACT_W-1:0] act_wire         [  ROWS][COLS+1];
  logic signed [WEIGHT_W-1:0] weight_wire      [ROWS+1][  COLS];
  logic                       act_valid_wire   [  ROWS][COLS+1];
  logic                       weight_valid_wire[ROWS+1][  COLS];
  logic                       acc_clear_wire   [  ROWS][COLS+1];

  // =========================================================
  // 입력 연결
  // =========================================================
  genvar i;
  generate
    for (i = 0; i < ROWS; i++) begin : g_input_act
      assign act_wire[i][0]       = act_i[i];
      assign act_valid_wire[i][0] = act_valid_i[i];
      assign acc_clear_wire[i][0] = acc_clear_i;
    end
    for (i = 0; i < COLS; i++) begin : g_input_weight
      assign weight_wire[0][i]       = weight_i[i];
      assign weight_valid_wire[0][i] = weight_valid_i[i];
    end
  endgenerate

  // =========================================================
  // PE 배열
  // =========================================================
  genvar row, col;
  generate
    for (row = 0; row < ROWS; row++) begin : g_row
      for (col = 0; col < COLS; col++) begin : g_col
        pe_os #(
            .ACT_W   (ACT_W),
            .WEIGHT_W(WEIGHT_W),
            .ACC_W   (ACC_W)
        ) u_pe (
            .aclk_i        (aclk_i),
            .aresetn_i     (aresetn_i),
            // inputs
            .act_valid_i   (act_valid_wire[row][col]),
            .weight_valid_i(weight_valid_wire[row][col]),
            .acc_clear_i   (acc_clear_wire[row][col]),
            .act_i         (act_wire[row][col]),
            .weight_i      (weight_wire[row][col]),
            // outputs
            .act_valid_o   (act_valid_wire[row][col+1]),
            .weight_valid_o(weight_valid_wire[row+1][col]),
            .acc_clear_o   (acc_clear_wire[row][col+1]),
            .act_o         (act_wire[row][col+1]),
            .weight_o      (weight_wire[row+1][col]),
            .acc_o         (acc_o[row][col])
        );
      end
    end
  endgenerate

endmodule

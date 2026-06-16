module tb_systolic_array_os;
  localparam int ROWS     = 2;
  localparam int COLS     = 3;
  localparam int K        = 4;
  localparam int ACT_W    = 8;
  localparam int WEIGHT_W = 8;
  localparam int ACC_W    = 32;

  logic                       aclk_i;
  logic                       aresetn_i;
  logic signed [   ACT_W-1:0] act_i          [ROWS];
  logic signed [WEIGHT_W-1:0] weight_i       [COLS];
  logic                       act_valid_i    [ROWS];
  logic                       weight_valid_i [COLS];
  logic                       acc_clear_i;
  logic signed [   ACC_W-1:0] acc_o          [ROWS][COLS];

  int signed a_mat [ROWS][K];
  int signed b_mat [K][COLS];
  int signed exp_c [ROWS][COLS];

  systolic_array_os #(
      .ROWS(ROWS),
      .COLS(COLS),
      .ACT_W(ACT_W),
      .WEIGHT_W(WEIGHT_W),
      .ACC_W(ACC_W)
  ) dut (
      .aclk_i(aclk_i),
      .aresetn_i(aresetn_i),
      .act_i(act_i),
      .weight_i(weight_i),
      .act_valid_i(act_valid_i),
      .weight_valid_i(weight_valid_i),
      .acc_clear_i(acc_clear_i),
      .acc_o(acc_o)
  );

  initial begin
    aclk_i = 1'b0;
    forever #5 aclk_i = ~aclk_i;
  end

  task automatic tick;
    begin
      @(posedge aclk_i);
      #1;
    end
  endtask

  task automatic drive_idle;
    int r;
    int c;
    begin
      for (r = 0; r < ROWS; r++) begin
        act_i[r]       = '0;
        act_valid_i[r] = 1'b0;
      end

      for (c = 0; c < COLS; c++) begin
        weight_i[c]       = '0;
        weight_valid_i[c] = 1'b0;
      end
    end
  endtask

  task automatic check_zero(input string phase);
    int r;
    int c;
    begin
      for (r = 0; r < ROWS; r++) begin
        for (c = 0; c < COLS; c++) begin
          if (acc_o[r][c] !== 0) begin
            $error("%s acc_o[%0d][%0d]: got %0d, expected 0",
                   phase, r, c, acc_o[r][c]);
            $finish;
          end
        end
      end
    end
  endtask

  task automatic check_acc(input string phase);
    int r;
    int c;
    begin
      for (r = 0; r < ROWS; r++) begin
        for (c = 0; c < COLS; c++) begin
          if (acc_o[r][c] !== exp_c[r][c]) begin
            $error("%s acc_o[%0d][%0d]: got %0d, expected %0d",
                   phase, r, c, acc_o[r][c], exp_c[r][c]);
            $finish;
          end
        end
      end
    end
  endtask

  initial begin
    int r;
    int c;
    int k;

    a_mat[0][0] = 1;
    a_mat[0][1] = -2;
    a_mat[0][2] = 3;
    a_mat[0][3] = -4;
    a_mat[1][0] = -5;
    a_mat[1][1] = 6;
    a_mat[1][2] = -7;
    a_mat[1][3] = 8;

    b_mat[0][0] = -1;
    b_mat[0][1] = 2;
    b_mat[0][2] = -3;
    b_mat[1][0] = 4;
    b_mat[1][1] = -5;
    b_mat[1][2] = 6;
    b_mat[2][0] = -7;
    b_mat[2][1] = 8;
    b_mat[2][2] = -9;
    b_mat[3][0] = 10;
    b_mat[3][1] = -11;
    b_mat[3][2] = 12;

    for (r = 0; r < ROWS; r++) begin
      for (c = 0; c < COLS; c++) begin
        exp_c[r][c] = 0;
        for (k = 0; k < K; k++) begin
          exp_c[r][c] += a_mat[r][k] * b_mat[k][c];
        end
      end
    end

    aresetn_i   = 1'b0;
    acc_clear_i = 1'b0;
    drive_idle();

    repeat (3) tick();
    check_zero("reset");

    aresetn_i = 1'b1;
    tick();

    acc_clear_i = 1'b1;
    tick();
    acc_clear_i = 1'b0;
    repeat (ROWS + COLS + 2) tick();
    check_zero("clear before stream");

    for (k = 0; k < K; k++) begin
      drive_idle();

      for (r = 0; r < ROWS; r++) begin
        act_i[r]       = a_mat[r][k][ACT_W-1:0];
        act_valid_i[r] = 1'b1;
      end

      for (c = 0; c < COLS; c++) begin
        weight_i[c]       = b_mat[k][c][WEIGHT_W-1:0];
        weight_valid_i[c] = 1'b1;
      end

      tick();
    end

    drive_idle();
    repeat (K + ROWS + COLS + 4) tick();
    check_acc("skewed signed matrix multiply");

    $display("tb_systolic_array_os_skew PASS");
    $finish;
  end
endmodule

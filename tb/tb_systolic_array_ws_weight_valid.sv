module tb_systolic_array_ws_weight_valid;
  localparam int ROWS     = 2;
  localparam int COLS     = 3;
  localparam int ACT_W    = 8;
  localparam int WEIGHT_W = 8;
  localparam int ACC_W    = 32;

  logic                         aclk_i;
  logic                         aresetn_i;
  logic                         weight_valid_i;
  logic                         act_valid_i[ROWS];
  logic signed [   ACT_W-1:0]   act_i[ROWS];
  logic signed [WEIGHT_W-1:0]   weight_i[COLS];
  logic                         acc_valid_o[COLS];
  logic signed [   ACC_W-1:0]   acc_o[COLS];

  int signed a_vec [ROWS];
  int signed b_mat [ROWS][COLS];
  int signed exp_c [COLS];
  int        seen  [COLS];

  systolic_array_ws #(
      .ROWS(ROWS),
      .COLS(COLS),
      .ACT_W(ACT_W),
      .WEIGHT_W(WEIGHT_W),
      .ACC_W(ACC_W)
  ) dut (
      .aclk_i(aclk_i),
      .aresetn_i(aresetn_i),
      .weight_valid_i(weight_valid_i),
      .act_valid_i(act_valid_i),
      .act_i(act_i),
      .weight_i(weight_i),
      .acc_valid_o(acc_valid_o),
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
    begin
      weight_valid_i = 1'b0;
      for (r = 0; r < ROWS; r++) begin
        act_valid_i[r] = 1'b0;
        act_i[r]       = '0;
      end
    end
  endtask

  task automatic check_outputs;
    int c;
    bit any_valid;
    begin
      any_valid = 1'b0;
      for (c = 0; c < COLS; c++) begin
        any_valid |= acc_valid_o[c];
      end

      if (any_valid) begin
        for (c = 0; c < COLS; c++) begin
          if (!acc_valid_o[c]) begin
            $error("acc_valid_o[%0d] did not align with other columns", c);
            $finish;
          end

          seen[c]++;
          if (acc_o[c] !== exp_c[c]) begin
            $error("acc_o[%0d]: got %0d, expected %0d", c, acc_o[c], exp_c[c]);
            $finish;
          end
        end
      end
    end
  endtask

  initial begin
    int r;
    int c;

    a_vec[0] = -2;
    a_vec[1] = 3;

    b_mat[0][0] = 4;
    b_mat[0][1] = -5;
    b_mat[0][2] = 6;
    b_mat[1][0] = -7;
    b_mat[1][1] = 8;
    b_mat[1][2] = -9;

    for (c = 0; c < COLS; c++) begin
      exp_c[c] = 0;
      seen[c]  = 0;
      for (r = 0; r < ROWS; r++) begin
        exp_c[c] += a_vec[r] * b_mat[r][c];
      end
    end

    aresetn_i = 1'b0;
    drive_idle();
    for (c = 0; c < COLS; c++) begin
      weight_i[c] = '0;
    end

    repeat (3) tick();
    aresetn_i = 1'b1;
    tick();

    for (r = ROWS - 1; r >= 0; r--) begin
      for (c = 0; c < COLS; c++) begin
        weight_i[c] = b_mat[r][c][WEIGHT_W-1:0];
      end
      weight_valid_i = 1'b1;
      tick();
    end

    drive_idle();
    tick();

    for (r = 0; r < ROWS; r++) begin
      act_valid_i[r] = 1'b1;
      act_i[r]       = a_vec[r][ACT_W-1:0];
    end
    tick();
    check_outputs();

    drive_idle();
    repeat (ROWS + COLS + 6) begin
      tick();
      check_outputs();
    end

    for (c = 0; c < COLS; c++) begin
      if (seen[c] != 1) begin
        $error("acc_valid_o[%0d] asserted %0d times, expected 1", c, seen[c]);
        $finish;
      end
    end

    $display("tb_systolic_array_ws_weight_valid PASS");
    $finish;
  end
endmodule

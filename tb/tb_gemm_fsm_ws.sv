module tb_gemm_fsm_ws;
  localparam int ROWS      = 2;
  localparam int COLS      = 3;
  localparam int ACT_W     = 8;
  localparam int WEIGHT_W  = 8;
  localparam int ACC_W     = 32;
  localparam int ADDR_W    = 8;
  localparam int M_SIZE    = 3;
  localparam int N_SIZE    = 5;
  localparam int K_SIZE    = 3;
  localparam int N_TILES   = 2;
  localparam int K_TILES   = 2;

  logic                         aclk_i;
  logic                         aresetn_i;
  logic                         start_i;
  logic        [  ADDR_W-1:0]   m_size_i;
  logic        [  ADDR_W-1:0]   n_size_i;
  logic        [  ADDR_W-1:0]   k_size_i;
  logic        [  ADDR_W-1:0]   act_base_addr_i;
  logic        [  ADDR_W-1:0]   weight_base_addr_i;
  logic        [  ADDR_W-1:0]   acc_base_addr_i;
  logic                         act_loader_en_o;
  logic        [  ADDR_W-1:0]   act_loader_addr_o;
  logic signed [   ACT_W-1:0]   act_loader_data_i[ROWS];
  logic                         act_loader_valid_i;
  logic                         weight_loader_en_o;
  logic        [  ADDR_W-1:0]   weight_loader_addr_o;
  logic signed [WEIGHT_W-1:0]   weight_loader_data_i[COLS];
  logic                         weight_loader_valid_i;
  logic signed [   ACT_W-1:0]   act_o[ROWS];
  logic signed [WEIGHT_W-1:0]   weight_o[COLS];
  logic                         act_valid_o[ROWS];
  logic                         weight_valid_o;
  logic                         acc_valid_i[COLS];
  logic signed [   ACC_W-1:0]   acc_i[COLS];
  logic                         acc_loader_en_o;
  logic        [  ADDR_W-1:0]   acc_loader_addr_o;
  logic signed [   ACC_W-1:0]   acc_loader_data_i[COLS];
  logic                         acc_loader_valid_i;
  logic                         accum_valid_o;
  logic                         accum_first_o;
  logic                         accum_lane_valid_o[COLS];
  logic signed [   ACC_W-1:0]   accum_old_data_o[COLS];
  logic signed [   ACC_W-1:0]   accum_partial_data_o[COLS];
  logic                         accum_valid_i;
  logic signed [   ACC_W-1:0]   accum_data_i[COLS];
  logic                         storer_valid_o;
  logic        [  ADDR_W-1:0]   storer_addr_o;
  logic signed [   ACC_W-1:0]   storer_data_o[COLS];
  logic                         done_o;

  logic signed [ACC_W-1:0]      c_mem[256][COLS];

  systolic_array_fsm_ws #(
      .ROWS(ROWS),
      .COLS(COLS),
      .ACT_W(ACT_W),
      .WEIGHT_W(WEIGHT_W),
      .ACC_W(ACC_W),
      .ADDR_W(ADDR_W)
  ) dut (
      .aclk_i(aclk_i),
      .aresetn_i(aresetn_i),
      .start_i(start_i),
      .m_size_i(m_size_i),
      .n_size_i(n_size_i),
      .k_size_i(k_size_i),
      .act_base_addr_i(act_base_addr_i),
      .weight_base_addr_i(weight_base_addr_i),
      .acc_base_addr_i(acc_base_addr_i),
      .act_loader_en_o(act_loader_en_o),
      .act_loader_addr_o(act_loader_addr_o),
      .act_loader_data_i(act_loader_data_i),
      .act_loader_valid_i(act_loader_valid_i),
      .weight_loader_en_o(weight_loader_en_o),
      .weight_loader_addr_o(weight_loader_addr_o),
      .weight_loader_data_i(weight_loader_data_i),
      .weight_loader_valid_i(weight_loader_valid_i),
      .act_o(act_o),
      .weight_o(weight_o),
      .act_valid_o(act_valid_o),
      .weight_valid_o(weight_valid_o),
      .acc_valid_i(acc_valid_i),
      .acc_i(acc_i),
      .acc_loader_en_o(acc_loader_en_o),
      .acc_loader_addr_o(acc_loader_addr_o),
      .acc_loader_data_i(acc_loader_data_i),
      .acc_loader_valid_i(acc_loader_valid_i),
      .accum_valid_o(accum_valid_o),
      .accum_first_o(accum_first_o),
      .accum_lane_valid_o(accum_lane_valid_o),
      .accum_old_data_o(accum_old_data_o),
      .accum_partial_data_o(accum_partial_data_o),
      .accum_valid_i(accum_valid_i),
      .accum_data_i(accum_data_i),
      .storer_valid_o(storer_valid_o),
      .storer_addr_o(storer_addr_o),
      .storer_data_o(storer_data_o),
      .done_o(done_o)
  );

  accumulator #(
      .LANES (COLS),
      .DATA_W(ACC_W)
  ) u_accumulator (
      .valid_i(accum_valid_o),
      .first_i(accum_first_o),
      .lane_valid_i(accum_lane_valid_o),
      .old_data_i(accum_old_data_o),
      .partial_data_i(accum_partial_data_o),
      .valid_o(accum_valid_i),
      .acc_data_o(accum_data_i)
  );

  initial begin
    aclk_i = 1'b0;
    forever #5 aclk_i = ~aclk_i;
  end

  always_ff @(posedge aclk_i) begin
    if (!aresetn_i) begin
      act_loader_valid_i    <= 1'b0;
      weight_loader_valid_i <= 1'b0;
      acc_loader_valid_i    <= 1'b0;
      act_loader_data_i     <= '{default: '0};
      weight_loader_data_i  <= '{default: '0};
      acc_loader_data_i     <= '{default: '0};
    end else begin
      act_loader_valid_i    <= act_loader_en_o;
      weight_loader_valid_i <= weight_loader_en_o;
      acc_loader_valid_i    <= acc_loader_en_o;

      for (int r = 0; r < ROWS; r++) begin
        act_loader_data_i[r] <= $signed({1'b0, act_loader_addr_o[ACT_W-2:0]}) + r;
      end

      for (int c = 0; c < COLS; c++) begin
        weight_loader_data_i[c] <= $signed({1'b0, weight_loader_addr_o[WEIGHT_W-2:0]}) - c;
        if (acc_loader_en_o) begin
          acc_loader_data_i[c] <= c_mem[acc_loader_addr_o - acc_base_addr_i][c];
        end else begin
          acc_loader_data_i[c] <= '0;
        end
      end
    end
  end

  task automatic tick;
    begin
      @(posedge aclk_i);
      #1;
    end
  endtask

  task automatic drive_acc_invalid;
    begin
      for (int c = 0; c < COLS; c++) begin
        acc_valid_i[c] = 1'b0;
        acc_i[c]       = '0;
      end
    end
  endtask

  task automatic drive_acc(input int m_idx, input int n_idx, input int k_idx);
    begin
      for (int c = 0; c < COLS; c++) begin
        acc_valid_i[c] = 1'b1;
        acc_i[c] = ACC_W'(1000 + (100 * m_idx) + (20 * n_idx) + (5 * k_idx) + c);
      end
      #1;
    end
  endtask

  function automatic int valid_cols(input int n_idx);
    begin
      valid_cols = (n_idx == N_TILES - 1) ? (N_SIZE - (n_idx * COLS)) : COLS;
    end
  endfunction

  function automatic int partial_value(input int m_idx, input int n_idx, input int k_idx,
                                       input int col);
    begin
      partial_value = 1000 + (100 * m_idx) + (20 * n_idx) + (5 * k_idx) + col;
    end
  endfunction

  task automatic check_bit(input string name, input logic got, input logic exp);
    begin
      if (got !== exp) begin
        $error("%s: got %0b, expected %0b", name, got, exp);
        $finish;
      end
    end
  endtask

  task automatic check_addr(input string name, input logic [ADDR_W-1:0] got,
                            input logic [ADDR_W-1:0] exp);
    begin
      if (got !== exp) begin
        $error("%s: got %0d, expected %0d", name, got, exp);
        $finish;
      end
    end
  endtask

  task automatic wait_weight_load(input logic [ADDR_W-1:0] exp_addr);
    bit seen;
    begin
      seen = 1'b0;
      for (int wait_cycle = 0; wait_cycle < 8; wait_cycle++) begin
        tick();
        if (weight_loader_en_o) begin
          check_addr("weight load addr", weight_loader_addr_o, exp_addr);
          seen = 1'b1;
          wait_cycle = 8;
        end
      end

      if (!seen) begin
        $error("weight load did not assert, expected addr %0d", exp_addr);
        $finish;
      end
    end
  endtask

  task automatic wait_act_load(input logic [ADDR_W-1:0] exp_addr);
    bit seen;
    begin
      seen = 1'b0;
      for (int wait_cycle = 0; wait_cycle < 8; wait_cycle++) begin
        tick();
        if (act_loader_en_o) begin
          check_addr("act load addr", act_loader_addr_o, exp_addr);
          seen = 1'b1;
          wait_cycle = 8;
        end
      end

      if (!seen) begin
        $error("act load did not assert");
        $finish;
      end
    end
  endtask

  task automatic wait_act_feed(input int m_idx, input int k_idx);
    bit seen;
    begin
      seen = 1'b0;
      for (int wait_cycle = 0; wait_cycle < 8; wait_cycle++) begin
        tick();
        if (act_valid_o[0]) begin
          check_act_feed(m_idx, k_idx);
          seen = 1'b1;
          wait_cycle = 8;
        end
      end

      if (!seen) begin
        $error("act feed did not assert");
        $finish;
      end
    end
  endtask

  task automatic wait_store(input int m_idx, input int n_idx, input int k_idx);
    bit seen;
    bit saw_partial_read;
    int exp_sum;
    int mem_idx;
    int v_cols;
    begin
      seen             = 1'b0;
      saw_partial_read = 1'b0;
      mem_idx          = (m_idx * N_TILES) + n_idx;
      v_cols           = valid_cols(n_idx);

      for (int wait_cycle = 0; wait_cycle < 12; wait_cycle++) begin
        if (storer_valid_o) begin
          check_addr("store addr", storer_addr_o, ADDR_W'(140 + (m_idx * N_TILES) + n_idx));

          if ((k_idx == 0) && saw_partial_read) begin
            $error("first K tile should not read previous partial sum");
            $finish;
          end

          if ((k_idx != 0) && !saw_partial_read) begin
            $error("K tile %0d did not read previous partial sum", k_idx);
            $finish;
          end

          for (int c = 0; c < COLS; c++) begin
            if (c < v_cols) begin
              exp_sum = c_mem[mem_idx][c] + partial_value(m_idx, n_idx, k_idx, c);

              if (storer_data_o[c] !== ACC_W'(exp_sum)) begin
                $error("store data col %0d: got %0d, expected %0d",
                       c, storer_data_o[c], exp_sum);
                $finish;
              end
            end else if (storer_data_o[c] !== '0) begin
              $error("masked store data col %0d: got %0d, expected 0", c, storer_data_o[c]);
              $finish;
            end
          end

          for (int c = 0; c < COLS; c++) begin
            c_mem[mem_idx][c] = storer_data_o[c];
          end

          seen = 1'b1;
          tick();
          wait_cycle = 12;
        end else begin
          tick();

          if (acc_loader_en_o) begin
            check_addr("partial read addr", acc_loader_addr_o, ADDR_W'(140 + mem_idx));
            saw_partial_read = 1'b1;
          end
        end
      end

      if (!seen) begin
        $error("store did not assert");
        $finish;
      end
    end
  endtask

  task automatic check_act_feed(input int m_idx, input int k_idx);
    int act_addr;
    begin
      act_addr = 10 + (k_idx * M_SIZE) + m_idx;

      for (int r = 0; r < ROWS; r++) begin
        check_bit("act_valid_o", act_valid_o[r], 1'b1);
        if ((k_idx == K_TILES - 1) && (r >= K_SIZE - ((K_TILES - 1) * ROWS))) begin
          if (act_o[r] !== '0) begin
            $error("edge K act_o[%0d]: got %0d, expected 0", r, act_o[r]);
            $finish;
          end
        end else if (act_o[r] !== ACT_W'(act_addr + r)) begin
          $error("act_o[%0d]: got %0d, expected %0d", r, act_o[r], act_addr + r);
          $finish;
        end
      end
    end
  endtask

  task automatic check_output_tile(input int m_idx, input int n_idx);
    begin
      for (int k_idx = 0; k_idx < K_TILES; k_idx++) begin
        for (int load = 0; load < ROWS; load++) begin
          wait_weight_load(ADDR_W'(80 + (((n_idx * K_TILES) + k_idx) * ROWS) +
                                  (ROWS - 1 - load)));
        end

        wait_act_load(ADDR_W'(10 + (k_idx * M_SIZE) + m_idx));
        wait_act_feed(m_idx, k_idx);
        drive_acc(m_idx, n_idx, k_idx);

        wait_store(m_idx, n_idx, k_idx);
        drive_acc_invalid();
      end
    end
  endtask

  initial begin
    start_i            = 1'b0;
    m_size_i           = ADDR_W'(M_SIZE);
    n_size_i           = ADDR_W'(N_SIZE);
    k_size_i           = ADDR_W'(K_SIZE);
    act_base_addr_i    = 8'd10;
    weight_base_addr_i = 8'd80;
    acc_base_addr_i    = 8'd140;
    drive_acc_invalid();
    for (int addr = 0; addr < 256; addr++) begin
      for (int c = 0; c < COLS; c++) begin
        c_mem[addr][c] = '0;
      end
    end

    aresetn_i = 1'b0;
    repeat (3) tick();
    check_bit("reset act_loader_en_o", act_loader_en_o, 1'b0);
    check_bit("reset weight_loader_en_o", weight_loader_en_o, 1'b0);
    check_bit("reset acc_loader_en_o", acc_loader_en_o, 1'b0);
    check_bit("reset storer_valid_o", storer_valid_o, 1'b0);
    check_bit("reset done_o", done_o, 1'b0);

    aresetn_i = 1'b1;
    tick();

    start_i = 1'b1;
    tick();
    start_i = 1'b0;

    for (int m_idx = 0; m_idx < M_SIZE; m_idx++) begin
      for (int n_idx = 0; n_idx < N_TILES; n_idx++) begin
        check_output_tile(m_idx, n_idx);
      end
    end

    tick();
    check_bit("done pulse", done_o, 1'b1);

    tick();
    check_bit("return idle done low", done_o, 1'b0);

    $display("tb_gemm_fsm_ws PASS");
    $finish;
  end
endmodule

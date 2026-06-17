module tb_gemm_fsm_os;
  localparam int ROWS     = 2;
  localparam int COLS     = 3;
  localparam int ACT_W    = 8;
  localparam int WEIGHT_W = 8;
  localparam int ACC_W    = 32;
  localparam int ADDR_W   = 8;
  localparam int M_SIZE   = 5;
  localparam int N_SIZE   = 7;
  localparam int K_SIZE   = 4;
  localparam int M_TILES  = 3;
  localparam int N_TILES  = 3;
  localparam int NUM_TILES = M_TILES * N_TILES;

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
  logic                         weight_valid_o[COLS];
  logic                         acc_clear_o;
  logic signed [   ACC_W-1:0]   acc_i[ROWS][COLS];
  logic                         storer_valid_o;
  logic        [  ADDR_W-1:0]   storer_addr_o;
  logic signed [   ACC_W-1:0]   storer_data_o[ROWS];
  logic                         done_o;

  systolic_array_fsm_os #(
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
      .acc_clear_o(acc_clear_o),
      .acc_i(acc_i),
      .storer_valid_o(storer_valid_o),
      .storer_addr_o(storer_addr_o),
      .storer_data_o(storer_data_o),
      .done_o(done_o)
  );

  initial begin
    aclk_i = 1'b0;
    forever #5 aclk_i = ~aclk_i;
  end

  always_ff @(posedge aclk_i) begin
    if (!aresetn_i) begin
      act_loader_valid_i    <= 1'b0;
      weight_loader_valid_i <= 1'b0;
      act_loader_data_i     <= '{default: '0};
      weight_loader_data_i  <= '{default: '0};
    end else begin
      act_loader_valid_i    <= act_loader_en_o;
      weight_loader_valid_i <= weight_loader_en_o;

      for (int r = 0; r < ROWS; r++) begin
        act_loader_data_i[r] <= $signed({1'b0, act_loader_addr_o[ACT_W-2:0]}) + r;
      end

      for (int c = 0; c < COLS; c++) begin
        weight_loader_data_i[c] <= $signed({1'b0, weight_loader_addr_o[WEIGHT_W-2:0]}) - c;
      end
    end
  end

  task automatic tick;
    begin
      @(posedge aclk_i);
      #1;
    end
  endtask

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

  function automatic int tile_m(input int m_idx);
    begin
      tile_m = (m_idx == M_TILES - 1) ? (M_SIZE - (m_idx * ROWS)) : ROWS;
    end
  endfunction

  function automatic int tile_n(input int n_idx);
    begin
      tile_n = (n_idx == N_TILES - 1) ? (N_SIZE - (n_idx * COLS)) : COLS;
    end
  endfunction

  task automatic check_act_valid(input int valid_rows, input logic exp);
    begin
      for (int r = 0; r < ROWS; r++) begin
        if (r < valid_rows) begin
          check_bit("act_valid active row", act_valid_o[r], exp);
        end else begin
          check_bit("act_valid edge row masked", act_valid_o[r], 1'b0);
        end
      end
    end
  endtask

  task automatic check_weight_valid(input int valid_cols, input logic exp);
    begin
      for (int c = 0; c < COLS; c++) begin
        if (c < valid_cols) begin
          check_bit("weight_valid active col", weight_valid_o[c], exp);
        end else begin
          check_bit("weight_valid edge col masked", weight_valid_o[c], 1'b0);
        end
      end
    end
  endtask

  task automatic check_store_data(input int col, input int valid_rows);
    begin
      for (int r = 0; r < ROWS; r++) begin
        if (r < valid_rows) begin
          if (storer_data_o[r] !== acc_i[r][col]) begin
            $error("store data row %0d col %0d: got %0d, expected %0d",
                   r, col, storer_data_o[r], acc_i[r][col]);
            $finish;
          end
        end else if (storer_data_o[r] !== '0) begin
          $error("store data masked row %0d: got %0d, expected 0", r, storer_data_o[r]);
          $finish;
        end
      end
    end
  endtask

  task automatic check_tile(input int tile_idx);
    int m_idx;
    int n_idx;
    int valid_rows;
    int valid_cols;
    int act_tile_base;
    int weight_tile_base;
    int acc_tile_base;
    begin
      m_idx = tile_idx / N_TILES;
      n_idx = tile_idx % N_TILES;
      valid_rows = tile_m(m_idx);
      valid_cols = tile_n(n_idx);
      act_tile_base = 10 + (m_idx * K_SIZE);
      weight_tile_base = 80 + (n_idx * K_SIZE);
      acc_tile_base = 140 + (tile_idx * COLS);

      tick();
      check_bit("clear pulse", acc_clear_o, 1'b1);
      check_bit("clear read off", act_loader_en_o, 1'b0);

      for (int k = 0; k < K_SIZE; k++) begin
        tick();
        check_bit("compute act en", act_loader_en_o, 1'b1);
        check_bit("compute weight en", weight_loader_en_o, 1'b1);
        check_addr("compute act addr", act_loader_addr_o, ADDR_W'(act_tile_base + k));
        check_addr("compute weight addr", weight_loader_addr_o, ADDR_W'(weight_tile_base + k));

        if (k == 0) begin
          check_act_valid(valid_rows, 1'b0);
          check_weight_valid(valid_cols, 1'b0);
        end else begin
          check_act_valid(valid_rows, 1'b1);
          check_weight_valid(valid_cols, 1'b1);
        end
      end

      tick();
      check_bit("drain read off", act_loader_en_o, 1'b0);
      check_bit("drain weight read off", weight_loader_en_o, 1'b0);
      check_act_valid(valid_rows, 1'b1);
      check_weight_valid(valid_cols, 1'b1);

      tick();
      check_act_valid(valid_rows, 1'b0);
      check_weight_valid(valid_cols, 1'b0);
      check_bit("drain no early store 1", storer_valid_o, 1'b0);

      tick();
      check_bit("drain no early store 2", storer_valid_o, 1'b0);

      tick();
      check_bit("drain no early store 3", storer_valid_o, 1'b0);

      tick();
      check_bit("drain no early store 4", storer_valid_o, 1'b0);

      for (int c = 0; c < valid_cols; c++) begin
        tick();
        check_bit("store valid", storer_valid_o, 1'b1);
        check_addr("store addr", storer_addr_o, ADDR_W'(acc_tile_base + c));
        check_store_data(c, valid_rows);
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

    for (int r = 0; r < ROWS; r++) begin
      for (int c = 0; c < COLS; c++) begin
        acc_i[r][c] = 32'sd1000 + 32'sd10 * r + c;
      end
    end

    aresetn_i = 1'b0;
    repeat (3) tick();
    check_bit("reset act_loader_en_o", act_loader_en_o, 1'b0);
    check_bit("reset weight_loader_en_o", weight_loader_en_o, 1'b0);
    check_bit("reset storer_valid_o", storer_valid_o, 1'b0);
    check_bit("reset done_o", done_o, 1'b0);

    aresetn_i = 1'b1;
    tick();

    start_i = 1'b1;
    tick();
    start_i = 1'b0;
    check_bit("start cycle clear low", acc_clear_o, 1'b0);
    check_bit("start cycle read low", act_loader_en_o, 1'b0);

    for (int tile_idx = 0; tile_idx < NUM_TILES; tile_idx++) begin
      check_tile(tile_idx);
    end

    tick();
    check_bit("done pulse", done_o, 1'b1);
    check_bit("done cycle store off", storer_valid_o, 1'b0);

    tick();
    check_bit("return idle done low", done_o, 1'b0);

    $display("tb_gemm_fsm_os PASS");
    $finish;
  end
endmodule

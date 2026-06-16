module systolic_array_fsm_ws #(
    parameter int ROWS     = 16,
    parameter int COLS     = 16,
    parameter int ACT_W    = 8,
    parameter int WEIGHT_W = 8,
    parameter int ACC_W    = 32,
    parameter int ADDR_W   = 10
) (
    input  logic                       aclk_i,
    input  logic                       aresetn_i,
    input  logic                       start_i,
    input  logic        [  ADDR_W-1:0] m_size_i,
    input  logic        [  ADDR_W-1:0] n_size_i,
    input  logic        [  ADDR_W-1:0] k_size_i,
    input  logic        [  ADDR_W-1:0] act_base_addr_i,
    input  logic        [  ADDR_W-1:0] weight_base_addr_i,
    input  logic        [  ADDR_W-1:0] acc_base_addr_i,
    // bram_loader (act) 인터페이스
    output logic                       act_loader_en_o,
    output logic        [  ADDR_W-1:0] act_loader_addr_o,
    input  logic signed [   ACT_W-1:0] act_loader_data_i    [ROWS],
    input  logic                       act_loader_valid_i,
    // bram_loader (weight) 인터페이스
    output logic                       weight_loader_en_o,
    output logic        [  ADDR_W-1:0] weight_loader_addr_o,
    input  logic signed [WEIGHT_W-1:0] weight_loader_data_i [COLS],
    input  logic                       weight_loader_valid_i,
    // systolic_array_ws 인터페이스
    output logic signed [   ACT_W-1:0] act_o                [ROWS],
    output logic signed [WEIGHT_W-1:0] weight_o             [COLS],
    output logic                       act_valid_o          [ROWS],
    output logic                       weight_valid_o,
    input  logic                       acc_valid_i          [COLS],
    input  logic signed [   ACC_W-1:0] acc_i                [COLS],
    // bram_loader (acc partial) 인터페이스
    output logic                       acc_loader_en_o,
    output logic        [  ADDR_W-1:0] acc_loader_addr_o,
    input  logic signed [   ACC_W-1:0] acc_loader_data_i    [COLS],
    input  logic                       acc_loader_valid_i,
    // accumulator 인터페이스
    output logic                       accum_valid_o,
    output logic                       accum_first_o,
    output logic                       accum_lane_valid_o   [COLS],
    output logic signed [   ACC_W-1:0] accum_old_data_o     [COLS],
    output logic signed [   ACC_W-1:0] accum_partial_data_o [COLS],
    input  logic                       accum_valid_i,
    input  logic signed [   ACC_W-1:0] accum_data_i         [COLS],
    // bram_storer 인터페이스
    output logic                       storer_valid_o,
    output logic        [  ADDR_W-1:0] storer_addr_o,
    output logic signed [   ACC_W-1:0] storer_data_o        [COLS],
    output logic                       done_o
);

  // WS GEMM 전체 제어 FSM.
  // systolic_array_ws는 한 번에 한 output row와 COLS개 column을 계산한다.
  // K가 ROWS보다 크면 중간합을 C BRAM에 저장하고 다음 K tile에서 다시 읽어 누적한다.
  // 메모리 layout 가정:
  //   A: k_tile마다 M개의 vector word, 각 word는 ROWS개 K-lane activation
  //   B: n_tile과 k_tile마다 ROWS개의 vector word, 각 word는 COLS개 weight
  //   C: m row와 n_tile마다 1개의 vector word, 각 word는 COLS개 result/partial sum
  typedef enum logic [3:0] {
    IDLE         = 4'd0,
    LOAD_WEIGHT  = 4'd1,  // 현재 K tile의 weight를 array 내부 PE에 load
    WEIGHT_FLUSH = 4'd2,  // 1-cycle BRAM valid 지연으로 마지막 weight를 전달
    READ_ACT     = 4'd3,  // 현재 m row의 activation vector를 읽기 요청
    WAIT_ACC     = 4'd4,  // array output valid 대기
    READ_PARTIAL = 4'd5,  // C partial sum read valid 대기 및 write-back
    DONE         = 4'd6
  } state_t;

  localparam int LOAD_CNT_W = $clog2(ROWS) + 1;

  localparam logic [ADDR_W-1:0] ROWS_W = ADDR_W'(ROWS);
  localparam logic [ADDR_W-1:0] COLS_W = ADDR_W'(COLS);

  state_t state, next_state;

  logic        [    ADDR_W-1:0] m_size_r;
  logic        [    ADDR_W-1:0] n_size_r;
  logic        [    ADDR_W-1:0] k_size_r;
  logic        [    ADDR_W-1:0] act_base_addr_r;
  logic        [    ADDR_W-1:0] weight_base_addr_r;
  logic        [    ADDR_W-1:0] acc_base_addr_r;

  logic        [    ADDR_W-1:0] n_tiles_r;
  logic        [    ADDR_W-1:0] k_tiles_r;
  logic        [    ADDR_W-1:0] m_idx_r;
  logic        [    ADDR_W-1:0] n_tile_idx_r;
  logic        [    ADDR_W-1:0] k_tile_idx_r;

  logic        [LOAD_CNT_W-1:0] weight_load_cnt;
  logic signed [     ACC_W-1:0] array_acc_r        [COLS];

  logic        [    ADDR_W-1:0] n_offset_w;
  logic        [    ADDR_W-1:0] k_offset_w;
  logic        [    ADDR_W-1:0] tile_n_w;
  logic        [    ADDR_W-1:0] tile_k_w;
  logic        [    ADDR_W-1:0] acc_addr_w;
  logic        [    ADDR_W-1:0] weight_load_row_w;
  logic                         last_k_tile_w;
  logic                         last_tile_r;
  logic                         first_k_tile_w;
  logic                         all_acc_valid_w;

  assign n_offset_w = n_tile_idx_r * COLS_W;
  assign k_offset_w = k_tile_idx_r * ROWS_W;
  assign tile_n_w = min_const(n_size_r - n_offset_w, COLS_W);
  assign tile_k_w = min_const(k_size_r - k_offset_w, ROWS_W);
  assign acc_addr_w = acc_base_addr_r + (m_idx_r * n_tiles_r) + n_tile_idx_r;
  assign weight_load_row_w = (ROWS_W - ADDR_W'(1)) - ADDR_W'(weight_load_cnt);
  assign first_k_tile_w = (k_tile_idx_r == '0);
  assign last_k_tile_w = (k_tile_idx_r == k_tiles_r - ADDR_W'(1));

  function automatic logic [ADDR_W-1:0] ceil_div_const(input logic [ADDR_W-1:0] value,
                                                       input logic [ADDR_W-1:0] denom);
    begin
      ceil_div_const = (value == '0) ? '0 : ((value - ADDR_W'(1)) / denom) + ADDR_W'(1);
    end
  endfunction

  function automatic logic [ADDR_W-1:0] min_const(input logic [ADDR_W-1:0] value,
                                                  input logic [ADDR_W-1:0] limit);
    begin
      min_const = (value > limit) ? limit : value;
    end
  endfunction

  always_comb begin
    all_acc_valid_w = 1'b1;
    for (int c = 0; c < COLS; c++) begin
      all_acc_valid_w = all_acc_valid_w && acc_valid_i[c];
    end
  end

  always_comb begin
    accum_lane_valid_o = '{default: 1'b0};
    for (int c = 0; c < COLS; c++) begin
      accum_lane_valid_o[c] = (ADDR_W'(c) < tile_n_w);
    end
  end

  always_comb begin
    accum_valid_o        = 1'b0;
    accum_first_o        = first_k_tile_w;
    accum_old_data_o     = '{default: '0};
    accum_partial_data_o = '{default: '0};

    if ((state == WAIT_ACC) && all_acc_valid_w && first_k_tile_w) begin
      accum_valid_o = 1'b1;
      for (int c = 0; c < COLS; c++) begin
        accum_partial_data_o[c] = acc_i[c];
      end
    end else if ((state == READ_PARTIAL) && acc_loader_valid_i) begin
      accum_valid_o = 1'b1;
      for (int c = 0; c < COLS; c++) begin
        accum_old_data_o[c]     = acc_loader_data_i[c];
        accum_partial_data_o[c] = array_acc_r[c];
      end
    end
  end

  always_ff @(posedge aclk_i) begin
    if (!aresetn_i) state <= IDLE;
    else state <= next_state;
  end

  always_comb begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start_i && (m_size_i != '0) && (n_size_i != '0) && (k_size_i != '0)) begin
          next_state = LOAD_WEIGHT;
        end else if (start_i) begin
          next_state = DONE;
        end
      end

      LOAD_WEIGHT: begin
        if (weight_load_cnt == LOAD_CNT_W'(ROWS - 1)) next_state = WEIGHT_FLUSH;
      end

      WEIGHT_FLUSH: begin
        next_state = READ_ACT;
      end

      READ_ACT: begin
        next_state = WAIT_ACC;
      end

      WAIT_ACC: begin
        if (all_acc_valid_w) begin
          if (first_k_tile_w) begin
            next_state = (last_k_tile_w && last_tile_r) ? DONE : LOAD_WEIGHT;
          end else begin
            next_state = READ_PARTIAL;
          end
        end
      end

      READ_PARTIAL: begin
        if (acc_loader_valid_i) begin
          next_state = (last_k_tile_w && last_tile_r) ? DONE : LOAD_WEIGHT;
        end
      end

      DONE: begin
        next_state = IDLE;
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

  always_ff @(posedge aclk_i) begin
    if (!aresetn_i) begin
      m_size_r           <= '0;
      n_size_r           <= '0;
      k_size_r           <= '0;
      act_base_addr_r    <= '0;
      weight_base_addr_r <= '0;
      acc_base_addr_r    <= '0;
      n_tiles_r          <= '0;
      k_tiles_r          <= '0;
      m_idx_r            <= '0;
      n_tile_idx_r       <= '0;
      k_tile_idx_r       <= '0;
      weight_load_cnt    <= '0;
      array_acc_r        <= '{default: '0};
      last_tile_r        <= 1'b0;
    end else begin
      case (state)
        IDLE: begin
          m_idx_r         <= '0;
          n_tile_idx_r    <= '0;
          k_tile_idx_r    <= '0;
          weight_load_cnt <= '0;
          array_acc_r     <= '{default: '0};
          last_tile_r     <= 1'b0;

          if (start_i) begin
            m_size_r           <= m_size_i;
            n_size_r           <= n_size_i;
            k_size_r           <= k_size_i;
            act_base_addr_r    <= act_base_addr_i;
            weight_base_addr_r <= weight_base_addr_i;
            acc_base_addr_r    <= acc_base_addr_i;
            n_tiles_r          <= ceil_div_const(n_size_i, COLS_W);
            k_tiles_r          <= ceil_div_const(k_size_i, ROWS_W);
            last_tile_r        <= (m_size_i == ADDR_W'(1)) &&
                                  (ceil_div_const(n_size_i, COLS_W) == ADDR_W'(1));
          end
        end

        LOAD_WEIGHT: begin
          if (weight_load_cnt == LOAD_CNT_W'(ROWS - 1)) begin
            weight_load_cnt <= '0;
          end else begin
            weight_load_cnt <= weight_load_cnt + LOAD_CNT_W'(1);
          end
        end

        WAIT_ACC: begin
          if (all_acc_valid_w) begin
            for (int c = 0; c < COLS; c++) begin
              array_acc_r[c] <= acc_i[c];
            end

            if (first_k_tile_w) begin
              if (!last_k_tile_w) begin
                k_tile_idx_r <= k_tile_idx_r + ADDR_W'(1);
              end else begin
                k_tile_idx_r <= '0;

                if (!last_tile_r) begin
                  if (n_tile_idx_r == n_tiles_r - ADDR_W'(1)) begin
                    n_tile_idx_r <= '0;
                    m_idx_r      <= m_idx_r + ADDR_W'(1);
                    last_tile_r  <= (m_idx_r + ADDR_W'(1) == m_size_r - ADDR_W'(1)) &&
                                    (n_tiles_r == ADDR_W'(1));
                  end else begin
                    n_tile_idx_r <= n_tile_idx_r + ADDR_W'(1);
                    last_tile_r  <= (m_idx_r == m_size_r - ADDR_W'(1)) &&
                                    (n_tile_idx_r + ADDR_W'(1) == n_tiles_r - ADDR_W'(1));
                  end
                end
              end
            end
          end
        end

        READ_PARTIAL: begin
          if (acc_loader_valid_i) begin
            if (!last_k_tile_w) begin
              k_tile_idx_r <= k_tile_idx_r + ADDR_W'(1);
            end else begin
              k_tile_idx_r <= '0;

              if (!last_tile_r) begin
                if (n_tile_idx_r == n_tiles_r - ADDR_W'(1)) begin
                  n_tile_idx_r <= '0;
                  m_idx_r      <= m_idx_r + ADDR_W'(1);
                  last_tile_r  <= (m_idx_r + ADDR_W'(1) == m_size_r - ADDR_W'(1)) &&
                                  (n_tiles_r == ADDR_W'(1));
                end else begin
                  n_tile_idx_r <= n_tile_idx_r + ADDR_W'(1);
                  last_tile_r  <= (m_idx_r == m_size_r - ADDR_W'(1)) &&
                                  (n_tile_idx_r + ADDR_W'(1) == n_tiles_r - ADDR_W'(1));
                end
              end else begin
                n_tile_idx_r <= n_tile_idx_r;
                m_idx_r      <= m_idx_r;
              end
            end
          end
        end

        default: begin
          // 유지
        end
      endcase
    end
  end

  always_ff @(posedge aclk_i) begin
    if (!aresetn_i) begin
      act_loader_en_o      <= 1'b0;
      act_loader_addr_o    <= '0;
      weight_loader_en_o   <= 1'b0;
      weight_loader_addr_o <= '0;
      acc_loader_en_o      <= 1'b0;
      acc_loader_addr_o    <= '0;
      done_o               <= 1'b0;
    end else begin
      act_loader_en_o    <= 1'b0;
      weight_loader_en_o <= 1'b0;
      acc_loader_en_o    <= 1'b0;
      done_o             <= 1'b0;

      case (state)
        LOAD_WEIGHT: begin
          weight_loader_en_o <= 1'b1;
          weight_loader_addr_o <= weight_base_addr_r +
                                  (((n_tile_idx_r * k_tiles_r) + k_tile_idx_r) * ROWS_W) +
                                  weight_load_row_w;
        end

        READ_ACT: begin
          act_loader_en_o   <= 1'b1;
          act_loader_addr_o <= act_base_addr_r + (k_tile_idx_r * m_size_r) + m_idx_r;
        end

        WAIT_ACC: begin
          if (all_acc_valid_w && !first_k_tile_w) begin
            acc_loader_en_o   <= 1'b1;
            acc_loader_addr_o <= acc_addr_w;
          end
        end

        DONE: begin
          done_o <= 1'b1;
        end

        default: begin
          // pulse 출력 외에는 기본값 유지
        end
      endcase
    end
  end

  always_comb begin
    storer_valid_o = accum_valid_i;
    storer_addr_o  = '0;
    storer_data_o  = '{default: '0};

    if (accum_valid_i) begin
      storer_addr_o = acc_addr_w;
      storer_data_o = accum_data_i;
    end
  end

  always_comb begin
    weight_o       = weight_loader_data_i;
    weight_valid_o = 1'b0;
    act_o          = '{default: '0};
    act_valid_o    = '{default: 1'b0};

    if ((state == LOAD_WEIGHT) || (state == WEIGHT_FLUSH) || (state == READ_ACT)) begin
      weight_valid_o = weight_loader_valid_i;
    end

    for (int r = 0; r < ROWS; r++) begin
      if (ADDR_W'(r) < tile_k_w) begin
        act_o[r] = act_loader_data_i[r];
      end else begin
        act_o[r] = '0;
      end

      // edge K에서도 valid chain이 끊기지 않도록 0 data를 valid로 흘린다.
      act_valid_o[r] = act_loader_valid_i;
    end
  end

endmodule

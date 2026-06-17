module systolic_array_fsm_os #(
    parameter int ROWS     = 16,
    parameter int COLS     = 16,
    parameter int ACT_W    = 8,
    parameter int WEIGHT_W = 8,
    parameter int ACC_W    = 32,
    parameter int ADDR_W = 9
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
    // systolic_array_os 인터페이스
    output logic signed [   ACT_W-1:0] act_o                [ROWS],
    output logic signed [WEIGHT_W-1:0] weight_o             [COLS],
    output logic                       act_valid_o          [ROWS],
    output logic                       weight_valid_o       [COLS],
    output logic                       acc_clear_o,
    input  logic signed [   ACC_W-1:0] acc_i                [ROWS][COLS],
    // bram_storer 인터페이스
    output logic                       storer_valid_o,
    output logic        [  ADDR_W-1:0] storer_addr_o,
    output logic signed [   ACC_W-1:0] storer_data_o        [ROWS],
    output logic                       done_o
);

  // OS GEMM 전체 제어 FSM.
  // 한 번 start되면 전체 MxN 결과를 tile 단위로 순회한다.
  // 메모리 layout 가정:
  //   A: m_tile마다 K개의 vector word, 각 word는 ROWS개 activation
  //   B: n_tile마다 K개의 vector word, 각 word는 COLS개 weight
  //   C: tile마다 COLS개의 vector word, 각 word는 ROWS개 result
  typedef enum logic [2:0] {
    IDLE    = 3'd0,
    CLEAR   = 3'd1,  // systolic array 내부 accumulator 초기화
    COMPUTE = 3'd2,  // K 방향으로 A/B vector를 stream
    DRAIN   = 3'd3,  // 마지막 입력이 array 내부를 지나갈 때까지 대기
    STORE   = 3'd4,  // PE에 남은 output tile을 column 단위로 저장
    DONE    = 3'd5   // 전체 GEMM 완료 pulse
  } state_t;

  // 마지막 입력 이후 결과가 우하단까지 전파되는 데 필요한 대기 cycle.
  localparam int DRAIN_LAST = ROWS + COLS - 2;
  localparam int DRAIN_CNT_W = $clog2(ROWS + COLS) + 1;
  localparam int STORE_CNT_W = $clog2(COLS) + 1;
  localparam int STORE_IDX_W = (COLS <= 1) ? 1 : $clog2(COLS);

  localparam logic [ADDR_W-1:0] ROWS_W = ADDR_W'(ROWS);
  localparam logic [ADDR_W-1:0] COLS_W = ADDR_W'(COLS);
  localparam logic [DRAIN_CNT_W-1:0] DRAIN_LAST_W = DRAIN_CNT_W'(DRAIN_LAST);

  state_t state, next_state;

  logic [     ADDR_W-1:0] m_size_r;
  logic [     ADDR_W-1:0] n_size_r;
  logic [     ADDR_W-1:0] k_size_r;
  logic [     ADDR_W-1:0] act_base_addr_r;
  logic [     ADDR_W-1:0] weight_base_addr_r;
  logic [     ADDR_W-1:0] acc_base_addr_r;

  logic [     ADDR_W-1:0] m_tiles_r;  // M 방향 tile 개수 = ceil(M / ROWS)
  logic [     ADDR_W-1:0] n_tiles_r;  // N 방향 tile 개수 = ceil(N / COLS)
  logic [     ADDR_W-1:0] m_tile_idx_r;  // 현재 M tile index
  logic [     ADDR_W-1:0] n_tile_idx_r;  // 현재 N tile index
  logic [     ADDR_W-1:0] k_cnt;  // 현재 tile 안에서 읽는 K offset
  logic [     ADDR_W-1:0] k_last_r;  // k_size_i - 1
  logic [DRAIN_CNT_W-1:0] drain_cnt;
  logic [STORE_CNT_W-1:0] store_cnt;
  logic [STORE_IDX_W-1:0] store_col_idx;

  logic [     ADDR_W-1:0] m_offset_w;
  logic [     ADDR_W-1:0] n_offset_w;
  logic [     ADDR_W-1:0] tile_linear_idx_w;
  logic [     ADDR_W-1:0] tile_m_w;
  logic [     ADDR_W-1:0] tile_n_w;
  logic [     ADDR_W-1:0] tile_m_last_w;
  logic [     ADDR_W-1:0] tile_n_last_w;
  logic                   last_tile_r;

  // 현재 tile의 global offset과 edge tile의 유효 row/col 수 계산.
  assign store_col_idx = store_cnt[STORE_IDX_W-1:0];
  assign m_offset_w = m_tile_idx_r * ROWS_W;
  assign n_offset_w = n_tile_idx_r * COLS_W;
  assign tile_linear_idx_w = (m_tile_idx_r * n_tiles_r) + n_tile_idx_r;
  assign tile_m_w = min_const(m_size_r - m_offset_w, ROWS_W);
  assign tile_n_w = min_const(n_size_r - n_offset_w, COLS_W);
  assign tile_m_last_w = (tile_m_w == '0) ? '0 : tile_m_w - ADDR_W'(1);
  assign tile_n_last_w = (tile_n_w == '0) ? '0 : tile_n_w - ADDR_W'(1);

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

  always_ff @(posedge aclk_i) begin
    if (!aresetn_i) state <= IDLE;
    else state <= next_state;
  end

  always_comb begin
    next_state = state;
    case (state)
      IDLE: begin
        // 크기가 0인 GEMM은 바로 DONE으로 처리한다.
        if (start_i && (m_size_i != '0) && (n_size_i != '0) && (k_size_i != '0)) begin
          next_state = CLEAR;
        end else if (start_i) begin
          next_state = DONE;
        end
      end

      CLEAR: begin
        next_state = COMPUTE;
      end

      COMPUTE: begin
        if (k_cnt == k_last_r) next_state = DRAIN;
      end

      DRAIN: begin
        if (drain_cnt == DRAIN_LAST_W) next_state = STORE;
      end

      STORE: begin
        // 현재 tile의 유효 column만 저장한 뒤 다음 tile 또는 DONE으로 이동한다.
        if (store_cnt == STORE_CNT_W'(tile_n_last_w)) begin
          next_state = last_tile_r ? DONE : CLEAR;
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
      m_tiles_r          <= '0;
      n_tiles_r          <= '0;
      m_tile_idx_r       <= '0;
      n_tile_idx_r       <= '0;
      k_cnt              <= '0;
      k_last_r           <= '0;
      drain_cnt          <= '0;
      store_cnt          <= '0;
      last_tile_r        <= 1'b0;
    end else begin
      case (state)
        IDLE: begin
          // start 시 전체 크기와 base address를 latch한다.
          m_tile_idx_r <= '0;
          n_tile_idx_r <= '0;
          k_cnt        <= '0;
          drain_cnt    <= '0;
          store_cnt    <= '0;
          last_tile_r  <= 1'b0;

          if (start_i) begin
            m_size_r           <= m_size_i;
            n_size_r           <= n_size_i;
            k_size_r           <= k_size_i;
            act_base_addr_r    <= act_base_addr_i;
            weight_base_addr_r <= weight_base_addr_i;
            acc_base_addr_r    <= acc_base_addr_i;
            m_tiles_r          <= ceil_div_const(m_size_i, ROWS_W);
            n_tiles_r          <= ceil_div_const(n_size_i, COLS_W);
            k_last_r           <= (k_size_i == '0) ? '0 : k_size_i - ADDR_W'(1);
            last_tile_r        <= (ceil_div_const(m_size_i, ROWS_W) == ADDR_W'(1)) &&
                                  (ceil_div_const(n_size_i, COLS_W) == ADDR_W'(1));
          end
        end

        COMPUTE: begin
          k_cnt <= (k_cnt == k_last_r) ? '0 : k_cnt + ADDR_W'(1);
        end

        DRAIN: begin
          drain_cnt <= (drain_cnt == DRAIN_LAST_W) ? '0 : drain_cnt + DRAIN_CNT_W'(1);
        end

        STORE: begin
          // N tile을 먼저 증가시키고, N 끝에 도달하면 다음 M tile로 넘어간다.
          if (store_cnt == STORE_CNT_W'(tile_n_last_w)) begin
            store_cnt <= '0;

            if (!last_tile_r) begin
              if (n_tile_idx_r == n_tiles_r - ADDR_W'(1)) begin
                n_tile_idx_r <= '0;
                m_tile_idx_r <= m_tile_idx_r + ADDR_W'(1);
                last_tile_r  <= (m_tile_idx_r + ADDR_W'(1) == m_tiles_r - ADDR_W'(1)) &&
                                (n_tiles_r == ADDR_W'(1));
              end else begin
                n_tile_idx_r <= n_tile_idx_r + ADDR_W'(1);
                last_tile_r  <= (m_tile_idx_r == m_tiles_r - ADDR_W'(1)) &&
                                (n_tile_idx_r + ADDR_W'(1) == n_tiles_r - ADDR_W'(1));
              end
            end
          end else begin
            store_cnt <= store_cnt + STORE_CNT_W'(1);
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
      acc_clear_o          <= 1'b0;
      storer_valid_o       <= 1'b0;
      storer_addr_o        <= '0;
      storer_data_o        <= '{default: '0};
      done_o               <= 1'b0;
    end else begin
      act_loader_en_o    <= 1'b0;
      weight_loader_en_o <= 1'b0;
      acc_clear_o        <= 1'b0;
      storer_valid_o     <= 1'b0;
      storer_data_o      <= '{default: '0};
      done_o             <= 1'b0;

      case (state)
        CLEAR: begin
          acc_clear_o <= 1'b1;
        end

        COMPUTE: begin
          // 각 주소는 현재 tile base + K offset.
          act_loader_en_o      <= 1'b1;
          act_loader_addr_o    <= act_base_addr_r + (m_tile_idx_r * k_size_r) + k_cnt;
          weight_loader_en_o   <= 1'b1;
          weight_loader_addr_o <= weight_base_addr_r + (n_tile_idx_r * k_size_r) + k_cnt;
        end

        STORE: begin
          // C tile은 act layout처럼 column 단위로 저장한다.
          // 한 주소에는 같은 column의 ROWS개 result가 들어간다.
          storer_valid_o <= 1'b1;
          storer_addr_o  <= acc_base_addr_r + (tile_linear_idx_w * COLS_W) + ADDR_W'(store_cnt);
          for (int r = 0; r < ROWS; r++) begin
            if (ADDR_W'(r) < tile_m_w) begin
              storer_data_o[r] <= acc_i[r][store_col_idx];
            end
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
    // loader data는 systolic array 입력으로 바로 연결한다.
    // valid는 edge M/N tile에서 유효 row/col만 켜도록 masking한다.
    act_o          = act_loader_data_i;
    weight_o       = weight_loader_data_i;
    act_valid_o    = '{default: 1'b0};
    weight_valid_o = '{default: 1'b0};

    for (int r = 0; r < ROWS; r++) begin
      act_valid_o[r] = act_loader_valid_i && (ADDR_W'(r) < tile_m_w);
    end

    for (int c = 0; c < COLS; c++) begin
      weight_valid_o[c] = weight_loader_valid_i && (ADDR_W'(c) < tile_n_w);
    end
  end

endmodule

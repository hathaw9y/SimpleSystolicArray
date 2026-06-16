module systolic_array_controller_ws #(
    parameter int ROWS   = 16,
    parameter int COLS   = 16,
    parameter int ADDR_W = 10,
    parameter int LEN_W  = 16,
    parameter logic [ADDR_W-1:0] ACT_BASE_ADDR    = '0,
    parameter logic [ADDR_W-1:0] WEIGHT_BASE_ADDR = '0,
    parameter logic [ADDR_W-1:0] ACC_BASE_ADDR    = '0
) (
    input logic aclk_i,
    input logic aresetn_i,

    input  logic       start_i,
    input  logic       clear_i,
    output logic       busy_o,
    output logic       done_o,
    output logic       error_o,
    output logic [3:0] state_o,

    input logic [ADDR_W-1:0] m_size_i,
    input logic [ADDR_W-1:0] n_size_i,
    input logic [ADDR_W-1:0] k_size_i,

    output logic              act_load_start_o,
    output logic [ADDR_W-1:0] act_load_base_addr_o,
    output logic [ LEN_W-1:0] act_load_length_o,
    input  logic              act_load_done_i,
    input  logic              act_load_error_i,

    output logic              weight_load_start_o,
    output logic [ADDR_W-1:0] weight_load_base_addr_o,
    output logic [ LEN_W-1:0] weight_load_length_o,
    input  logic              weight_load_done_i,
    input  logic              weight_load_error_i,

    output logic              engine_start_o,
    output logic [ADDR_W-1:0] engine_m_size_o,
    output logic [ADDR_W-1:0] engine_n_size_o,
    output logic [ADDR_W-1:0] engine_k_size_o,
    output logic [ADDR_W-1:0] engine_act_base_addr_o,
    output logic [ADDR_W-1:0] engine_weight_base_addr_o,
    output logic [ADDR_W-1:0] engine_acc_base_addr_o,
    input  logic              engine_done_i,

    output logic              result_store_start_o,
    output logic [ADDR_W-1:0] result_store_base_addr_o,
    output logic [ LEN_W-1:0] result_store_length_o,
    input  logic              result_store_done_i,
    input  logic              result_store_error_i
);

  typedef enum logic [3:0] {
    ST_IDLE,
    ST_START_ACT,
    ST_WAIT_ACT,
    ST_START_WEIGHT,
    ST_WAIT_WEIGHT,
    ST_START_ENGINE,
    ST_WAIT_ENGINE,
    ST_START_RESULT,
    ST_WAIT_RESULT,
    ST_DONE,
    ST_ERROR
  } state_t;

  state_t state_r;
  state_t state_n;

  logic [ADDR_W-1:0] m_size_r;
  logic [ADDR_W-1:0] n_size_r;
  logic [ADDR_W-1:0] k_size_r;
  logic [ LEN_W-1:0] act_length_r;
  logic [ LEN_W-1:0] weight_length_r;
  logic [ LEN_W-1:0] result_length_r;
  logic [ LEN_W-1:0] n_tiles_w;
  logic [ LEN_W-1:0] k_tiles_w;

  logic              accept_start_w;

  function automatic logic [LEN_W-1:0] ceil_div_const(
      input logic [ADDR_W-1:0] value,
      input int                divisor
  );
    logic [ADDR_W:0] adjusted;
    begin
      if (value == '0) begin
        ceil_div_const = '0;
      end else begin
        adjusted       = {1'b0, value} + (ADDR_W + 1)'(divisor - 1);
        ceil_div_const = LEN_W'(adjusted / (ADDR_W + 1)'(divisor));
      end
    end
  endfunction

  function automatic logic [LEN_W-1:0] mul_len_addr(
      input logic [ LEN_W-1:0] lhs,
      input logic [ADDR_W-1:0] rhs
  );
    logic [LEN_W+ADDR_W-1:0] product;
    begin
      product = lhs * rhs;
      mul_len_addr = product[LEN_W-1:0];
    end
  endfunction

  assign accept_start_w = start_i && ((state_r == ST_IDLE) || (state_r == ST_DONE));
  assign n_tiles_w = ceil_div_const(n_size_i, COLS);
  assign k_tiles_w = ceil_div_const(k_size_i, ROWS);

  assign busy_o  = (state_r != ST_IDLE) && (state_r != ST_DONE) && (state_r != ST_ERROR);
  assign done_o  = (state_r == ST_DONE);
  assign error_o = (state_r == ST_ERROR);
  assign state_o = state_r;

  assign act_load_start_o = (state_r == ST_START_ACT);
  assign act_load_base_addr_o = ACT_BASE_ADDR;
  assign act_load_length_o = act_length_r;

  assign weight_load_start_o = (state_r == ST_START_WEIGHT);
  assign weight_load_base_addr_o = WEIGHT_BASE_ADDR;
  assign weight_load_length_o = weight_length_r;

  assign engine_start_o = (state_r == ST_START_ENGINE);
  assign engine_m_size_o = m_size_r;
  assign engine_n_size_o = n_size_r;
  assign engine_k_size_o = k_size_r;
  assign engine_act_base_addr_o = ACT_BASE_ADDR;
  assign engine_weight_base_addr_o = WEIGHT_BASE_ADDR;
  assign engine_acc_base_addr_o = ACC_BASE_ADDR;

  assign result_store_start_o = (state_r == ST_START_RESULT);
  assign result_store_base_addr_o = ACC_BASE_ADDR;
  assign result_store_length_o = result_length_r;

  always_comb begin
    state_n = state_r;

    case (state_r)
      ST_IDLE: begin
        if (start_i) begin
          state_n = ST_START_ACT;
        end
      end

      ST_START_ACT: begin
        state_n = ST_WAIT_ACT;
      end

      ST_WAIT_ACT: begin
        if (act_load_error_i) begin
          state_n = ST_ERROR;
        end else if (act_load_done_i) begin
          state_n = ST_START_WEIGHT;
        end
      end

      ST_START_WEIGHT: begin
        state_n = ST_WAIT_WEIGHT;
      end

      ST_WAIT_WEIGHT: begin
        if (weight_load_error_i) begin
          state_n = ST_ERROR;
        end else if (weight_load_done_i) begin
          state_n = ST_START_ENGINE;
        end
      end

      ST_START_ENGINE: begin
        state_n = ST_WAIT_ENGINE;
      end

      ST_WAIT_ENGINE: begin
        if (engine_done_i) begin
          state_n = ST_START_RESULT;
        end
      end

      ST_START_RESULT: begin
        state_n = ST_WAIT_RESULT;
      end

      ST_WAIT_RESULT: begin
        if (result_store_error_i) begin
          state_n = ST_ERROR;
        end else if (result_store_done_i) begin
          state_n = ST_DONE;
        end
      end

      ST_DONE: begin
        if (clear_i) begin
          state_n = ST_IDLE;
        end else if (start_i) begin
          state_n = ST_START_ACT;
        end
      end

      ST_ERROR: begin
        if (clear_i) begin
          state_n = ST_IDLE;
        end
      end

      default: begin
        state_n = ST_IDLE;
      end
    endcase
  end

  always_ff @(posedge aclk_i) begin
    if (!aresetn_i) begin
      state_r         <= ST_IDLE;
      m_size_r        <= '0;
      n_size_r        <= '0;
      k_size_r        <= '0;
      act_length_r    <= '0;
      weight_length_r <= '0;
      result_length_r <= '0;
    end else begin
      state_r <= state_n;

      if (accept_start_w) begin
        m_size_r        <= m_size_i;
        n_size_r        <= n_size_i;
        k_size_r        <= k_size_i;
        act_length_r    <= mul_len_addr(k_tiles_w, m_size_i);
        weight_length_r <= mul_len_addr(mul_len_addr(n_tiles_w, k_tiles_w), ADDR_W'(ROWS));
        result_length_r <= mul_len_addr(n_tiles_w, m_size_i);
      end
    end
  end

endmodule

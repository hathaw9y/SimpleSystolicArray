module tb_systolic_array_controller_ws;
  localparam int ROWS   = 2;
  localparam int COLS   = 3;
  localparam int ADDR_W = 8;
  localparam int LEN_W  = 8;
  localparam logic [ADDR_W-1:0] ACT_BASE_ADDR    = ADDR_W'(10);
  localparam logic [ADDR_W-1:0] WEIGHT_BASE_ADDR = ADDR_W'(80);
  localparam logic [ADDR_W-1:0] ACC_BASE_ADDR    = ADDR_W'(140);

  localparam logic [3:0] ST_IDLE         = 4'd0;
  localparam logic [3:0] ST_START_ACT    = 4'd1;
  localparam logic [3:0] ST_WAIT_ACT     = 4'd2;
  localparam logic [3:0] ST_START_WEIGHT = 4'd3;
  localparam logic [3:0] ST_WAIT_WEIGHT  = 4'd4;
  localparam logic [3:0] ST_START_ENGINE = 4'd5;
  localparam logic [3:0] ST_WAIT_ENGINE  = 4'd6;
  localparam logic [3:0] ST_START_RESULT = 4'd7;
  localparam logic [3:0] ST_WAIT_RESULT  = 4'd8;
  localparam logic [3:0] ST_DONE         = 4'd9;
  localparam logic [3:0] ST_ERROR        = 4'd10;

  logic aclk_i;
  logic aresetn_i;
  logic start_i;
  logic clear_i;
  logic busy_o;
  logic done_o;
  logic error_o;
  logic [3:0] state_o;

  logic [ADDR_W-1:0] m_size_i;
  logic [ADDR_W-1:0] n_size_i;
  logic [ADDR_W-1:0] k_size_i;

  logic act_load_start_o;
  logic [ADDR_W-1:0] act_load_base_addr_o;
  logic [LEN_W-1:0] act_load_length_o;
  logic act_load_done_i;
  logic act_load_error_i;

  logic weight_load_start_o;
  logic [ADDR_W-1:0] weight_load_base_addr_o;
  logic [LEN_W-1:0] weight_load_length_o;
  logic weight_load_done_i;
  logic weight_load_error_i;

  logic engine_start_o;
  logic [ADDR_W-1:0] engine_m_size_o;
  logic [ADDR_W-1:0] engine_n_size_o;
  logic [ADDR_W-1:0] engine_k_size_o;
  logic [ADDR_W-1:0] engine_act_base_addr_o;
  logic [ADDR_W-1:0] engine_weight_base_addr_o;
  logic [ADDR_W-1:0] engine_acc_base_addr_o;
  logic engine_done_i;

  logic result_store_start_o;
  logic [ADDR_W-1:0] result_store_base_addr_o;
  logic [LEN_W-1:0] result_store_length_o;
  logic result_store_done_i;
  logic result_store_error_i;

  systolic_array_controller_ws #(
      .ROWS(ROWS),
      .COLS(COLS),
      .ADDR_W(ADDR_W),
      .LEN_W(LEN_W),
      .ACT_BASE_ADDR(ACT_BASE_ADDR),
      .WEIGHT_BASE_ADDR(WEIGHT_BASE_ADDR),
      .ACC_BASE_ADDR(ACC_BASE_ADDR)
  ) dut (
      .aclk_i(aclk_i),
      .aresetn_i(aresetn_i),
      .start_i(start_i),
      .clear_i(clear_i),
      .busy_o(busy_o),
      .done_o(done_o),
      .error_o(error_o),
      .state_o(state_o),
      .m_size_i(m_size_i),
      .n_size_i(n_size_i),
      .k_size_i(k_size_i),
      .act_load_start_o(act_load_start_o),
      .act_load_base_addr_o(act_load_base_addr_o),
      .act_load_length_o(act_load_length_o),
      .act_load_done_i(act_load_done_i),
      .act_load_error_i(act_load_error_i),
      .weight_load_start_o(weight_load_start_o),
      .weight_load_base_addr_o(weight_load_base_addr_o),
      .weight_load_length_o(weight_load_length_o),
      .weight_load_done_i(weight_load_done_i),
      .weight_load_error_i(weight_load_error_i),
      .engine_start_o(engine_start_o),
      .engine_m_size_o(engine_m_size_o),
      .engine_n_size_o(engine_n_size_o),
      .engine_k_size_o(engine_k_size_o),
      .engine_act_base_addr_o(engine_act_base_addr_o),
      .engine_weight_base_addr_o(engine_weight_base_addr_o),
      .engine_acc_base_addr_o(engine_acc_base_addr_o),
      .engine_done_i(engine_done_i),
      .result_store_start_o(result_store_start_o),
      .result_store_base_addr_o(result_store_base_addr_o),
      .result_store_length_o(result_store_length_o),
      .result_store_done_i(result_store_done_i),
      .result_store_error_i(result_store_error_i)
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
    begin
      start_i = 1'b0;
      clear_i = 1'b0;
      m_size_i = '0;
      n_size_i = '0;
      k_size_i = '0;
      act_load_done_i = 1'b0;
      act_load_error_i = 1'b0;
      weight_load_done_i = 1'b0;
      weight_load_error_i = 1'b0;
      engine_done_i = 1'b0;
      result_store_done_i = 1'b0;
      result_store_error_i = 1'b0;
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

  task automatic check_word(input string name, input logic [ADDR_W-1:0] got,
                            input logic [ADDR_W-1:0] exp);
    begin
      if (got !== exp) begin
        $error("%s: got %0d, expected %0d", name, got, exp);
        $finish;
      end
    end
  endtask

  task automatic check_len(input string name, input logic [LEN_W-1:0] got,
                           input logic [LEN_W-1:0] exp);
    begin
      if (got !== exp) begin
        $error("%s: got %0d, expected %0d", name, got, exp);
        $finish;
      end
    end
  endtask

  task automatic check_state(input string name, input logic [3:0] exp);
    begin
      if (state_o !== exp) begin
        $error("%s: state got %0d, expected %0d", name, state_o, exp);
        $finish;
      end
    end
  endtask

  task automatic pulse_start;
    begin
      start_i = 1'b1;
      tick();
      start_i = 1'b0;
    end
  endtask

  task automatic pulse_clear;
    begin
      clear_i = 1'b1;
      tick();
      clear_i = 1'b0;
    end
  endtask

  task automatic pulse_act_done;
    begin
      act_load_done_i = 1'b1;
      tick();
      act_load_done_i = 1'b0;
    end
  endtask

  task automatic pulse_weight_done;
    begin
      weight_load_done_i = 1'b1;
      tick();
      weight_load_done_i = 1'b0;
    end
  endtask

  task automatic pulse_engine_done;
    begin
      engine_done_i = 1'b1;
      tick();
      engine_done_i = 1'b0;
    end
  endtask

  task automatic pulse_result_done;
    begin
      result_store_done_i = 1'b1;
      tick();
      result_store_done_i = 1'b0;
    end
  endtask

  task automatic set_sizes(input int m_size, input int n_size, input int k_size);
    begin
      m_size_i = ADDR_W'(m_size);
      n_size_i = ADDR_W'(n_size);
      k_size_i = ADDR_W'(k_size);
    end
  endtask

  initial begin
    drive_idle();
    aresetn_i = 1'b0;
    repeat (3) tick();

    check_state("reset state", ST_IDLE);
    check_bit("reset busy", busy_o, 1'b0);
    check_bit("reset done", done_o, 1'b0);
    check_bit("reset error", error_o, 1'b0);

    aresetn_i = 1'b1;
    tick();

    // ROWS=2, COLS=3, M=5, N=7, K=4:
    // k_tiles=2, n_tiles=3, act_length=10, weight_length=12, result_length=15.
    set_sizes(5, 7, 4);
    pulse_start();

    check_state("activation start state", ST_START_ACT);
    check_bit("activation start pulse", act_load_start_o, 1'b1);
    check_bit("busy during activation start", busy_o, 1'b1);
    check_word("activation base", act_load_base_addr_o, ACT_BASE_ADDR);
    check_len("activation length", act_load_length_o, LEN_W'(10));
    check_word("engine m latched", engine_m_size_o, ADDR_W'(5));
    check_word("engine n latched", engine_n_size_o, ADDR_W'(7));
    check_word("engine k latched", engine_k_size_o, ADDR_W'(4));

    tick();
    check_state("wait activation", ST_WAIT_ACT);
    check_bit("activation pulse clears", act_load_start_o, 1'b0);

    set_sizes(9, 9, 9);
    start_i = 1'b1;
    tick();
    start_i = 1'b0;
    check_state("busy ignores new start", ST_WAIT_ACT);
    check_word("latched m unchanged", engine_m_size_o, ADDR_W'(5));
    check_len("latched act length unchanged", act_load_length_o, LEN_W'(10));

    pulse_act_done();
    check_state("weight start state", ST_START_WEIGHT);
    check_bit("weight start pulse", weight_load_start_o, 1'b1);
    check_word("weight base", weight_load_base_addr_o, WEIGHT_BASE_ADDR);
    check_len("weight length", weight_load_length_o, LEN_W'(12));

    tick();
    check_state("wait weight", ST_WAIT_WEIGHT);
    check_bit("weight pulse clears", weight_load_start_o, 1'b0);

    pulse_weight_done();
    check_state("engine start state", ST_START_ENGINE);
    check_bit("engine start pulse", engine_start_o, 1'b1);
    check_word("engine act base", engine_act_base_addr_o, ACT_BASE_ADDR);
    check_word("engine weight base", engine_weight_base_addr_o, WEIGHT_BASE_ADDR);
    check_word("engine acc base", engine_acc_base_addr_o, ACC_BASE_ADDR);

    tick();
    check_state("wait engine", ST_WAIT_ENGINE);
    check_bit("engine pulse clears", engine_start_o, 1'b0);

    pulse_engine_done();
    check_state("result start state", ST_START_RESULT);
    check_bit("result start pulse", result_store_start_o, 1'b1);
    check_word("result base uses acc base", result_store_base_addr_o, ACC_BASE_ADDR);
    check_len("result length", result_store_length_o, LEN_W'(15));

    tick();
    check_state("wait result", ST_WAIT_RESULT);
    check_bit("result pulse clears", result_store_start_o, 1'b0);

    pulse_result_done();
    check_state("done state", ST_DONE);
    check_bit("done high", done_o, 1'b1);
    check_bit("busy low in done", busy_o, 1'b0);

    pulse_clear();
    check_state("clear done", ST_IDLE);
    check_bit("done clears", done_o, 1'b0);

    set_sizes(4, 4, 4);
    pulse_start();
    tick();
    check_state("second op wait activation", ST_WAIT_ACT);
    check_len("second op act length", act_load_length_o, LEN_W'(8));
    check_len("second op weight length", weight_load_length_o, LEN_W'(8));
    check_len("second op result length", result_store_length_o, LEN_W'(8));

    act_load_error_i = 1'b1;
    tick();
    act_load_error_i = 1'b0;
    check_state("activation error state", ST_ERROR);
    check_bit("error high", error_o, 1'b1);
    check_bit("busy low in error", busy_o, 1'b0);

    pulse_clear();
    check_state("clear error", ST_IDLE);
    check_bit("error clears", error_o, 1'b0);

    $display("tb_systolic_array_controller_ws PASS");
    $finish;
  end
endmodule

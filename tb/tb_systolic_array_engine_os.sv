module tb_systolic_array_engine_os;
  localparam int ROWS     = 2;
  localparam int COLS     = 2;
  localparam int ACT_W    = 8;
  localparam int WEIGHT_W = 8;
  localparam int ACC_W    = 32;
  localparam int ADDR_W   = 8;

  logic                         aclk_i;
  logic                         aresetn_i;
  logic                         start_i;
  logic        [  ADDR_W-1:0]   m_size_i;
  logic        [  ADDR_W-1:0]   n_size_i;
  logic        [  ADDR_W-1:0]   k_size_i;
  logic        [  ADDR_W-1:0]   act_base_addr_i;
  logic        [  ADDR_W-1:0]   weight_base_addr_i;
  logic        [  ADDR_W-1:0]   acc_base_addr_i;
  logic                         act_bram_en_o;
  logic        [  ADDR_W-1:0]   act_bram_addr_o;
  logic        [ROWS*ACT_W-1:0] act_bram_data_i;
  logic                         weight_bram_en_o;
  logic        [  ADDR_W-1:0]   weight_bram_addr_o;
  logic        [COLS*WEIGHT_W-1:0] weight_bram_data_i;
  logic                         acc_bram_en_o;
  logic                         acc_bram_we_o;
  logic        [  ADDR_W-1:0]   acc_bram_addr_o;
  logic        [ROWS*ACC_W-1:0] acc_bram_data_o;
  logic                         done_o;

  logic [ROWS*ACT_W-1:0]        act_mem[256];
  logic [COLS*WEIGHT_W-1:0]     weight_mem[256];
  logic [ROWS*ACC_W-1:0]        acc_mem[256];
  logic [ROWS*ACT_W-1:0]        act_bram_data_s0;
  logic [COLS*WEIGHT_W-1:0]     weight_bram_data_s0;

  systolic_array_engine_os #(
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
      .act_bram_en_o(act_bram_en_o),
      .act_bram_addr_o(act_bram_addr_o),
      .act_bram_data_i(act_bram_data_i),
      .weight_bram_en_o(weight_bram_en_o),
      .weight_bram_addr_o(weight_bram_addr_o),
      .weight_bram_data_i(weight_bram_data_i),
      .acc_bram_en_o(acc_bram_en_o),
      .acc_bram_we_o(acc_bram_we_o),
      .acc_bram_addr_o(acc_bram_addr_o),
      .acc_bram_data_o(acc_bram_data_o),
      .done_o(done_o)
  );

  initial begin
    aclk_i = 1'b0;
    forever #5 aclk_i = ~aclk_i;
  end

  function automatic logic [ROWS*ACT_W-1:0] pack_act(input int signed lane0,
                                                     input int signed lane1);
    begin
      pack_act = '0;
      pack_act[0*ACT_W+:ACT_W] = ACT_W'(lane0);
      pack_act[1*ACT_W+:ACT_W] = ACT_W'(lane1);
    end
  endfunction

  function automatic logic [COLS*WEIGHT_W-1:0] pack_weight(input int signed lane0,
                                                           input int signed lane1);
    begin
      pack_weight = '0;
      pack_weight[0*WEIGHT_W+:WEIGHT_W] = WEIGHT_W'(lane0);
      pack_weight[1*WEIGHT_W+:WEIGHT_W] = WEIGHT_W'(lane1);
    end
  endfunction

  task automatic tick;
    begin
      @(posedge aclk_i);
      #1;
    end
  endtask

  task automatic wait_done;
    bit seen;
    begin
      seen = 1'b0;
      for (int t = 0; t < 200; t++) begin
        tick();
        if (done_o) begin
          seen = 1'b1;
          t = 200;
        end
      end
      if (!seen) begin
        $error("done_o did not assert");
        $finish;
      end
    end
  endtask

  task automatic check_acc_word(input int addr, input int signed lane0, input int signed lane1);
    begin
      if ($signed(acc_mem[addr][0*ACC_W+:ACC_W]) !== ACC_W'(lane0)) begin
        $error("acc addr %0d lane0: got %0d, expected %0d",
               addr, $signed(acc_mem[addr][0*ACC_W+:ACC_W]), lane0);
        $finish;
      end
      if ($signed(acc_mem[addr][1*ACC_W+:ACC_W]) !== ACC_W'(lane1)) begin
        $error("acc addr %0d lane1: got %0d, expected %0d",
               addr, $signed(acc_mem[addr][1*ACC_W+:ACC_W]), lane1);
        $finish;
      end
    end
  endtask

  always_ff @(posedge aclk_i) begin
    if (!aresetn_i) begin
      act_bram_data_i    <= '0;
      weight_bram_data_i <= '0;
      act_bram_data_s0   <= '0;
      weight_bram_data_s0 <= '0;
    end else begin
      if (act_bram_en_o) begin
        act_bram_data_s0 <= act_mem[act_bram_addr_o];
      end
      if (weight_bram_en_o) begin
        weight_bram_data_s0 <= weight_mem[weight_bram_addr_o];
      end
      act_bram_data_i    <= act_bram_data_s0;
      weight_bram_data_i <= weight_bram_data_s0;
      if (acc_bram_en_o && acc_bram_we_o) begin
        acc_mem[acc_bram_addr_o] <= acc_bram_data_o;
      end
    end
  end

  initial begin
    start_i            = 1'b0;
    m_size_i           = ADDR_W'(2);
    n_size_i           = ADDR_W'(2);
    k_size_i           = ADDR_W'(2);
    act_base_addr_i    = ADDR_W'(10);
    weight_base_addr_i = ADDR_W'(80);
    acc_base_addr_i    = ADDR_W'(140);

    for (int i = 0; i < 256; i++) begin
      act_mem[i]    = '0;
      weight_mem[i] = '0;
      acc_mem[i]    = '0;
    end

    // A = [[1, 2], [3, 4]], OS layout: addr = m_tile * K + k.
    act_mem[10] = pack_act(1, 3);
    act_mem[11] = pack_act(2, 4);

    // B = [[5, 6], [7, 8]], OS layout: addr = n_tile * K + k.
    weight_mem[80] = pack_weight(5, 6);
    weight_mem[81] = pack_weight(7, 8);

    aresetn_i = 1'b0;
    repeat (3) tick();
    aresetn_i = 1'b1;
    tick();

    start_i = 1'b1;
    tick();
    start_i = 1'b0;

    wait_done();
    check_acc_word(140, 19, 43);
    check_acc_word(141, 22, 50);

    $display("tb_systolic_array_engine_os PASS");
    $finish;
  end
endmodule

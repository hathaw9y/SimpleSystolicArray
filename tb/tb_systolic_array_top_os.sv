module tb_systolic_array_top_os;
  localparam int ROWS     = 2;
  localparam int COLS     = 2;
  localparam int ACT_W    = 8;
  localparam int WEIGHT_W = 8;
  localparam int ACC_W    = 32;
  localparam int ADDR_W   = 8;
  localparam int LEN_W    = 8;
  localparam int AXI_ADDR_W = 4;
  localparam int AXI_DATA_W = 32;

  localparam logic [ADDR_W-1:0] ACT_BASE_ADDR    = ADDR_W'(10);
  localparam logic [ADDR_W-1:0] WEIGHT_BASE_ADDR = ADDR_W'(80);
  localparam logic [ADDR_W-1:0] ACC_BASE_ADDR    = ADDR_W'(140);

  logic S_AXI_ACLK;
  logic S_AXI_ARESETN;
  logic [AXI_ADDR_W-1:0] S_AXI_AWADDR;
  logic [2:0] S_AXI_AWPROT;
  logic S_AXI_AWVALID;
  logic S_AXI_AWREADY;
  logic [AXI_DATA_W-1:0] S_AXI_WDATA;
  logic [AXI_DATA_W/8-1:0] S_AXI_WSTRB;
  logic S_AXI_WVALID;
  logic S_AXI_WREADY;
  logic [1:0] S_AXI_BRESP;
  logic S_AXI_BVALID;
  logic S_AXI_BREADY;
  logic [AXI_ADDR_W-1:0] S_AXI_ARADDR;
  logic [2:0] S_AXI_ARPROT;
  logic S_AXI_ARVALID;
  logic S_AXI_ARREADY;
  logic [AXI_DATA_W-1:0] S_AXI_RDATA;
  logic [1:0] S_AXI_RRESP;
  logic S_AXI_RVALID;
  logic S_AXI_RREADY;

  logic [ROWS*ACT_W-1:0] s_axis_act_tdata;
  logic s_axis_act_tvalid;
  logic s_axis_act_tready;
  logic s_axis_act_tlast;

  logic [COLS*WEIGHT_W-1:0] s_axis_weight_tdata;
  logic s_axis_weight_tvalid;
  logic s_axis_weight_tready;
  logic s_axis_weight_tlast;

  logic [ROWS*ACC_W-1:0] m_axis_result_tdata;
  logic m_axis_result_tvalid;
  logic m_axis_result_tready;
  logic m_axis_result_tlast;

  logic act_wr_bram_en_o;
  logic act_wr_bram_we_o;
  logic [ADDR_W-1:0] act_wr_bram_addr_o;
  logic [ROWS*ACT_W-1:0] act_wr_bram_data_o;
  logic act_rd_bram_en_o;
  logic [ADDR_W-1:0] act_rd_bram_addr_o;
  logic [ROWS*ACT_W-1:0] act_rd_bram_data_i;

  logic weight_wr_bram_en_o;
  logic weight_wr_bram_we_o;
  logic [ADDR_W-1:0] weight_wr_bram_addr_o;
  logic [COLS*WEIGHT_W-1:0] weight_wr_bram_data_o;
  logic weight_rd_bram_en_o;
  logic [ADDR_W-1:0] weight_rd_bram_addr_o;
  logic [COLS*WEIGHT_W-1:0] weight_rd_bram_data_i;

  logic acc_wr_bram_en_o;
  logic acc_wr_bram_we_o;
  logic [ADDR_W-1:0] acc_wr_bram_addr_o;
  logic [ROWS*ACC_W-1:0] acc_wr_bram_data_o;
  logic acc_rd_bram_en_o;
  logic [ADDR_W-1:0] acc_rd_bram_addr_o;
  logic [ROWS*ACC_W-1:0] acc_rd_bram_data_i;

  logic [ROWS*ACT_W-1:0] act_mem[256];
  logic [COLS*WEIGHT_W-1:0] weight_mem[256];
  logic [ROWS*ACC_W-1:0] acc_mem[256];

  systolic_array_top_os #(
      .ROWS            (ROWS),
      .COLS            (COLS),
      .ACT_W           (ACT_W),
      .WEIGHT_W        (WEIGHT_W),
      .ACC_W           (ACC_W),
      .ADDR_W          (ADDR_W),
      .LEN_W           (LEN_W),
      .ACT_BASE_ADDR   (ACT_BASE_ADDR),
      .WEIGHT_BASE_ADDR(WEIGHT_BASE_ADDR),
      .ACC_BASE_ADDR   (ACC_BASE_ADDR)
  ) dut (
      .S_AXI_ACLK(S_AXI_ACLK),
      .S_AXI_ARESETN(S_AXI_ARESETN),
      .S_AXI_AWADDR(S_AXI_AWADDR),
      .S_AXI_AWPROT(S_AXI_AWPROT),
      .S_AXI_AWVALID(S_AXI_AWVALID),
      .S_AXI_AWREADY(S_AXI_AWREADY),
      .S_AXI_WDATA(S_AXI_WDATA),
      .S_AXI_WSTRB(S_AXI_WSTRB),
      .S_AXI_WVALID(S_AXI_WVALID),
      .S_AXI_WREADY(S_AXI_WREADY),
      .S_AXI_BRESP(S_AXI_BRESP),
      .S_AXI_BVALID(S_AXI_BVALID),
      .S_AXI_BREADY(S_AXI_BREADY),
      .S_AXI_ARADDR(S_AXI_ARADDR),
      .S_AXI_ARPROT(S_AXI_ARPROT),
      .S_AXI_ARVALID(S_AXI_ARVALID),
      .S_AXI_ARREADY(S_AXI_ARREADY),
      .S_AXI_RDATA(S_AXI_RDATA),
      .S_AXI_RRESP(S_AXI_RRESP),
      .S_AXI_RVALID(S_AXI_RVALID),
      .S_AXI_RREADY(S_AXI_RREADY),
      .s_axis_act_tdata(s_axis_act_tdata),
      .s_axis_act_tvalid(s_axis_act_tvalid),
      .s_axis_act_tready(s_axis_act_tready),
      .s_axis_act_tlast(s_axis_act_tlast),
      .s_axis_weight_tdata(s_axis_weight_tdata),
      .s_axis_weight_tvalid(s_axis_weight_tvalid),
      .s_axis_weight_tready(s_axis_weight_tready),
      .s_axis_weight_tlast(s_axis_weight_tlast),
      .m_axis_result_tdata(m_axis_result_tdata),
      .m_axis_result_tvalid(m_axis_result_tvalid),
      .m_axis_result_tready(m_axis_result_tready),
      .m_axis_result_tlast(m_axis_result_tlast),
      .act_wr_bram_en_o(act_wr_bram_en_o),
      .act_wr_bram_we_o(act_wr_bram_we_o),
      .act_wr_bram_addr_o(act_wr_bram_addr_o),
      .act_wr_bram_data_o(act_wr_bram_data_o),
      .act_rd_bram_en_o(act_rd_bram_en_o),
      .act_rd_bram_addr_o(act_rd_bram_addr_o),
      .act_rd_bram_data_i(act_rd_bram_data_i),
      .weight_wr_bram_en_o(weight_wr_bram_en_o),
      .weight_wr_bram_we_o(weight_wr_bram_we_o),
      .weight_wr_bram_addr_o(weight_wr_bram_addr_o),
      .weight_wr_bram_data_o(weight_wr_bram_data_o),
      .weight_rd_bram_en_o(weight_rd_bram_en_o),
      .weight_rd_bram_addr_o(weight_rd_bram_addr_o),
      .weight_rd_bram_data_i(weight_rd_bram_data_i),
      .acc_wr_bram_en_o(acc_wr_bram_en_o),
      .acc_wr_bram_we_o(acc_wr_bram_we_o),
      .acc_wr_bram_addr_o(acc_wr_bram_addr_o),
      .acc_wr_bram_data_o(acc_wr_bram_data_o),
      .acc_rd_bram_en_o(acc_rd_bram_en_o),
      .acc_rd_bram_addr_o(acc_rd_bram_addr_o),
      .acc_rd_bram_data_i(acc_rd_bram_data_i)
  );

  initial begin
    S_AXI_ACLK = 1'b0;
    forever #5 S_AXI_ACLK = ~S_AXI_ACLK;
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

  function automatic logic [ROWS*ACC_W-1:0] pack_acc(input int signed lane0,
                                                     input int signed lane1);
    begin
      pack_acc = '0;
      pack_acc[0*ACC_W+:ACC_W] = ACC_W'(lane0);
      pack_acc[1*ACC_W+:ACC_W] = ACC_W'(lane1);
    end
  endfunction

  task automatic tick;
    begin
      @(posedge S_AXI_ACLK);
      #1;
    end
  endtask

  task automatic drive_idle;
    begin
      S_AXI_AWADDR = '0;
      S_AXI_AWPROT = '0;
      S_AXI_AWVALID = 1'b0;
      S_AXI_WDATA = '0;
      S_AXI_WSTRB = '0;
      S_AXI_WVALID = 1'b0;
      S_AXI_BREADY = 1'b0;
      S_AXI_ARADDR = '0;
      S_AXI_ARPROT = '0;
      S_AXI_ARVALID = 1'b0;
      S_AXI_RREADY = 1'b0;

      s_axis_act_tdata = '0;
      s_axis_act_tvalid = 1'b0;
      s_axis_act_tlast = 1'b0;

      s_axis_weight_tdata = '0;
      s_axis_weight_tvalid = 1'b0;
      s_axis_weight_tlast = 1'b0;

      m_axis_result_tready = 1'b0;
    end
  endtask

  task automatic check_word(input string name, input logic [AXI_DATA_W-1:0] got,
                            input logic [AXI_DATA_W-1:0] exp);
    begin
      if (got !== exp) begin
        $error("%s: got 0x%08x, expected 0x%08x", name, got, exp);
        $finish;
      end
    end
  endtask

  task automatic check_acc_word(input string name, input logic [ROWS*ACC_W-1:0] got,
                                input logic [ROWS*ACC_W-1:0] exp);
    begin
      if (got !== exp) begin
        $error("%s: got 0x%016x, expected 0x%016x", name, got, exp);
        $finish;
      end
    end
  endtask

  task automatic axi_write(input logic [AXI_ADDR_W-1:0] addr,
                           input logic [AXI_DATA_W-1:0] data,
                           input logic [AXI_DATA_W/8-1:0] strb);
    bit aw_done;
    bit w_done;
    begin
      aw_done = 1'b0;
      w_done = 1'b0;

      S_AXI_AWADDR = addr;
      S_AXI_AWVALID = 1'b1;
      S_AXI_WDATA = data;
      S_AXI_WSTRB = strb;
      S_AXI_WVALID = 1'b1;
      S_AXI_BREADY = 1'b1;

      for (int cycle = 0; cycle < 16; cycle++) begin
        #1;
        aw_done |= (S_AXI_AWVALID && S_AXI_AWREADY);
        w_done |= (S_AXI_WVALID && S_AXI_WREADY);
        tick();

        if (aw_done) begin
          S_AXI_AWVALID = 1'b0;
        end
        if (w_done) begin
          S_AXI_WVALID = 1'b0;
        end
        if (S_AXI_BVALID) begin
          check_word("write response", {30'd0, S_AXI_BRESP}, 32'd0);
          tick();
          S_AXI_BREADY = 1'b0;
          cycle = 16;
        end
      end

      if (!aw_done || !w_done) begin
        $error("AXI write handshake failed");
        $finish;
      end

      S_AXI_AWADDR = '0;
      S_AXI_WDATA = '0;
      S_AXI_WSTRB = '0;
    end
  endtask

  task automatic axi_read(input logic [AXI_ADDR_W-1:0] addr,
                          output logic [AXI_DATA_W-1:0] data);
    bit ar_done;
    begin
      ar_done = 1'b0;
      data = '0;

      S_AXI_ARADDR = addr;
      S_AXI_ARVALID = 1'b1;
      S_AXI_RREADY = 1'b1;

      for (int cycle = 0; cycle < 16; cycle++) begin
        #1;
        ar_done |= (S_AXI_ARVALID && S_AXI_ARREADY);
        if (S_AXI_RVALID) begin
          data = S_AXI_RDATA;
          check_word("read response", {30'd0, S_AXI_RRESP}, 32'd0);
          tick();
          S_AXI_ARVALID = 1'b0;
          S_AXI_RREADY = 1'b0;
          cycle = 16;
        end else begin
          tick();
          if (ar_done) begin
            S_AXI_ARVALID = 1'b0;
          end
        end
      end

      if (!ar_done) begin
        $error("AXI read address handshake failed");
        $finish;
      end

      S_AXI_ARADDR = '0;
    end
  endtask

  task automatic send_act_beat(input logic [ROWS*ACT_W-1:0] data,
                               input logic last);
    begin
      s_axis_act_tdata = data;
      s_axis_act_tlast = last;
      s_axis_act_tvalid = 1'b1;

      for (int cycle = 0; cycle < 16; cycle++) begin
        if (s_axis_act_tready) begin
          tick();
          s_axis_act_tvalid = 1'b0;
          s_axis_act_tlast = 1'b0;
          s_axis_act_tdata = '0;
          cycle = 16;
        end else begin
          tick();
        end
      end

      if (s_axis_act_tvalid) begin
        $error("activation stream did not become ready");
        $finish;
      end
    end
  endtask

  task automatic send_weight_beat(input logic [COLS*WEIGHT_W-1:0] data,
                                  input logic last);
    begin
      s_axis_weight_tdata = data;
      s_axis_weight_tlast = last;
      s_axis_weight_tvalid = 1'b1;

      for (int cycle = 0; cycle < 16; cycle++) begin
        if (s_axis_weight_tready) begin
          tick();
          s_axis_weight_tvalid = 1'b0;
          s_axis_weight_tlast = 1'b0;
          s_axis_weight_tdata = '0;
          cycle = 16;
        end else begin
          tick();
        end
      end

      if (s_axis_weight_tvalid) begin
        $error("weight stream did not become ready");
        $finish;
      end
    end
  endtask

  task automatic wait_done_via_axi;
    logic [AXI_DATA_W-1:0] rd_data;
    bit seen;
    begin
      seen = 1'b0;
      for (int cycle = 0; cycle < 64; cycle++) begin
        axi_read(4'h0, rd_data);
        if (rd_data[0]) begin
          seen = 1'b1;
          cycle = 64;
        end else begin
          tick();
        end
      end

      if (!seen) begin
        $error("top done status did not assert");
        $finish;
      end
    end
  endtask

  task automatic collect_result_stream;
    logic [ROWS*ACC_W-1:0] expected[2];
    bit seen;
    begin
      expected[0] = pack_acc(19, 43);
      expected[1] = pack_acc(22, 50);
      m_axis_result_tready = 1'b1;

      for (int beat = 0; beat < 2; beat++) begin
        seen = 1'b0;
        for (int cycle = 0; cycle < 32; cycle++) begin
          tick();
          if (m_axis_result_tvalid) begin
            seen = 1'b1;
            cycle = 32;
          end
        end

        if (!seen) begin
          $error("result stream beat %0d did not assert valid", beat);
          $finish;
        end

        check_acc_word("result stream", m_axis_result_tdata, expected[beat]);
        if (m_axis_result_tlast !== (beat == 1)) begin
          $error("result tlast at beat %0d: got %0b", beat, m_axis_result_tlast);
          $finish;
        end

        tick();

        if (beat == 1) begin
          if (m_axis_result_tvalid) begin
            $error("unexpected result beat after tlast");
            $finish;
          end
        end
      end

      m_axis_result_tready = 1'b0;
    end
  endtask

  always_ff @(posedge S_AXI_ACLK) begin
    if (!S_AXI_ARESETN) begin
      act_rd_bram_data_i <= '0;
      weight_rd_bram_data_i <= '0;
      acc_rd_bram_data_i <= '0;
    end else begin
      if (act_wr_bram_en_o && act_wr_bram_we_o) begin
        act_mem[act_wr_bram_addr_o] <= act_wr_bram_data_o;
      end
      if (weight_wr_bram_en_o && weight_wr_bram_we_o) begin
        weight_mem[weight_wr_bram_addr_o] <= weight_wr_bram_data_o;
      end
      if (acc_wr_bram_en_o && acc_wr_bram_we_o) begin
        acc_mem[acc_wr_bram_addr_o] <= acc_wr_bram_data_o;
      end

      if (act_rd_bram_en_o) begin
        act_rd_bram_data_i <= act_mem[act_rd_bram_addr_o];
      end
      if (weight_rd_bram_en_o) begin
        weight_rd_bram_data_i <= weight_mem[weight_rd_bram_addr_o];
      end
      if (acc_rd_bram_en_o) begin
        acc_rd_bram_data_i <= acc_mem[acc_rd_bram_addr_o];
      end
    end
  end

  initial begin
    logic [AXI_DATA_W-1:0] rd_data;

    drive_idle();
    for (int i = 0; i < 256; i++) begin
      act_mem[i] = '0;
      weight_mem[i] = '0;
      acc_mem[i] = '0;
    end

    S_AXI_ARESETN = 1'b0;
    repeat (3) tick();
    S_AXI_ARESETN = 1'b1;
    tick();

    axi_write(4'h4, 32'd2, 4'hf);
    axi_write(4'h8, 32'd2, 4'hf);
    axi_write(4'hc, 32'd2, 4'hf);
    axi_write(4'h0, 32'h1, 4'hf);

    send_act_beat(pack_act(1, 3), 1'b0);
    send_act_beat(pack_act(2, 4), 1'b1);

    send_weight_beat(pack_weight(5, 6), 1'b0);
    send_weight_beat(pack_weight(7, 8), 1'b1);

    collect_result_stream();
    wait_done_via_axi();
    check_acc_word("acc row 0", acc_mem[ACC_BASE_ADDR], pack_acc(19, 43));
    check_acc_word("acc row 1", acc_mem[ACC_BASE_ADDR+ADDR_W'(1)], pack_acc(22, 50));

    axi_read(4'h0, rd_data);
    check_word("done sticky status", rd_data, 32'h1);
    axi_write(4'h0, 32'h2, 4'hf);

    $display("tb_systolic_array_top_os PASS");
    $finish;
  end
endmodule

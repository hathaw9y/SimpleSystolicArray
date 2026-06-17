module tb_systolic_array_top_os_identity;
  localparam int ROWS       = 16;
  localparam int COLS       = 16;
  localparam int ACT_W      = 8;
  localparam int WEIGHT_W   = 8;
  localparam int ACC_W      = 32;
  localparam int ADDR_W     = 9;
  localparam int LEN_W      = 8;
  localparam int AXI_ADDR_W = 4;
  localparam int AXI_DATA_W = 32;

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
  logic                  s_axis_act_tvalid;
  logic                  s_axis_act_tready;
  logic                  s_axis_act_tlast;
  logic [COLS*WEIGHT_W-1:0] s_axis_weight_tdata;
  logic                     s_axis_weight_tvalid;
  logic                     s_axis_weight_tready;
  logic                     s_axis_weight_tlast;
  logic [ROWS*ACC_W-1:0] m_axis_result_tdata;
  logic                  m_axis_result_tvalid;
  logic                  m_axis_result_tready;
  logic                  m_axis_result_tlast;

  systolic_array_top_os #(
      .ROWS(ROWS),
      .COLS(COLS),
      .ACT_W(ACT_W),
      .WEIGHT_W(WEIGHT_W),
      .ACC_W(ACC_W),
      .ADDR_W(ADDR_W),
      .LEN_W(LEN_W)
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
      .m_axis_result_tlast(m_axis_result_tlast)
  );

  initial begin
    S_AXI_ACLK = 1'b0;
    forever #5 S_AXI_ACLK = ~S_AXI_ACLK;
  end

  function automatic int pattern(input int idx);
    begin
      pattern = (idx == 7 || idx == 15) ? 0 : ((idx % 8) + 1);
    end
  endfunction

  function automatic logic [ROWS*ACT_W-1:0] pack_act_column(input int col);
    begin
      pack_act_column = '0;
      for (int r = 0; r < ROWS; r++) begin
        pack_act_column[r*ACT_W+:ACT_W] = ACT_W'(pattern(col));
      end
    end
  endfunction

  function automatic logic [COLS*WEIGHT_W-1:0] pack_identity_weight_row(input int row);
    begin
      pack_identity_weight_row = '0;
      for (int c = 0; c < COLS; c++) begin
        pack_identity_weight_row[c*WEIGHT_W+:WEIGHT_W] = WEIGHT_W'((c == row) ? 1 : 0);
      end
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

  task automatic axi_write(input logic [AXI_ADDR_W-1:0] addr,
                           input logic [AXI_DATA_W-1:0] data);
    bit aw_done;
    bit w_done;
    begin
      aw_done = 1'b0;
      w_done = 1'b0;
      S_AXI_AWADDR = addr;
      S_AXI_AWVALID = 1'b1;
      S_AXI_WDATA = data;
      S_AXI_WSTRB = 4'hf;
      S_AXI_WVALID = 1'b1;
      S_AXI_BREADY = 1'b1;
      for (int cycle = 0; cycle < 32; cycle++) begin
        #1;
        aw_done |= S_AXI_AWVALID && S_AXI_AWREADY;
        w_done |= S_AXI_WVALID && S_AXI_WREADY;
        tick();
        if (aw_done) S_AXI_AWVALID = 1'b0;
        if (w_done) S_AXI_WVALID = 1'b0;
        if (S_AXI_BVALID) begin
          S_AXI_BREADY = 1'b0;
          cycle = 32;
        end
      end
      if (!aw_done || !w_done) begin
        $error("AXI write failed");
        $finish;
      end
    end
  endtask

  task automatic send_act(input logic [ROWS*ACT_W-1:0] data, input logic last);
    begin
      s_axis_act_tdata = data;
      s_axis_act_tlast = last;
      s_axis_act_tvalid = 1'b1;
      while (!s_axis_act_tready) tick();
      tick();
      s_axis_act_tvalid = 1'b0;
      s_axis_act_tlast = 1'b0;
      s_axis_act_tdata = '0;
    end
  endtask

  task automatic send_weight(input logic [COLS*WEIGHT_W-1:0] data, input logic last);
    begin
      s_axis_weight_tdata = data;
      s_axis_weight_tlast = last;
      s_axis_weight_tvalid = 1'b1;
      while (!s_axis_weight_tready) tick();
      tick();
      s_axis_weight_tvalid = 1'b0;
      s_axis_weight_tlast = 1'b0;
      s_axis_weight_tdata = '0;
    end
  endtask

  task automatic check_result_column(input int col);
    int got;
    begin
      for (int r = 0; r < ROWS; r++) begin
        got = $signed(m_axis_result_tdata[r*ACC_W+:ACC_W]);
        if (got != pattern(col)) begin
          $error("result row %0d col %0d: got %0d, expected %0d",
                 r, col, got, pattern(col));
          $finish;
        end
      end
      if (m_axis_result_tlast !== (col == COLS - 1)) begin
        $error("result tlast col %0d: got %0b", col, m_axis_result_tlast);
        $finish;
      end
    end
  endtask

  initial begin
    drive_idle();
    S_AXI_ARESETN = 1'b0;
    repeat (3) tick();
    S_AXI_ARESETN = 1'b1;
    tick();

    axi_write(4'h4, 32'd16);
    axi_write(4'h8, 32'd16);
    axi_write(4'hc, 32'd16);
    axi_write(4'h0, 32'h1);

    for (int k = 0; k < 16; k++) begin
      send_act(pack_act_column(k), k == 15);
    end
    for (int k = 0; k < 16; k++) begin
      send_weight(pack_identity_weight_row(k), k == 15);
    end

    m_axis_result_tready = 1'b1;
    for (int col = 0; col < 16; col++) begin
      int seen;
      seen = 0;
      for (int cycle = 0; cycle < 4096; cycle++) begin
        tick();
        if (m_axis_result_tvalid) begin
          seen = 1;
          cycle = 4096;
        end
      end
      if (!seen) begin
        $error("missing result col %0d", col);
        $finish;
      end
      check_result_column(col);
    end
    m_axis_result_tready = 1'b0;

    $display("tb_systolic_array_top_os_identity PASS");
    $finish;
  end
endmodule

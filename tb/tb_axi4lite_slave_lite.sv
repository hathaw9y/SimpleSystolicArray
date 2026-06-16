module tb_axi4lite_slave_lite;
  localparam int DATA_W = 32;
  localparam int ADDR_W = 4;

  logic              S_AXI_ACLK;
  logic              S_AXI_ARESETN;
  logic [ADDR_W-1:0] S_AXI_AWADDR;
  logic [2:0]        S_AXI_AWPROT;
  logic              S_AXI_AWVALID;
  logic              S_AXI_AWREADY;
  logic [DATA_W-1:0] S_AXI_WDATA;
  logic [DATA_W/8-1:0] S_AXI_WSTRB;
  logic              S_AXI_WVALID;
  logic              S_AXI_WREADY;
  logic [1:0]        S_AXI_BRESP;
  logic              S_AXI_BVALID;
  logic              S_AXI_BREADY;
  logic [ADDR_W-1:0] S_AXI_ARADDR;
  logic [2:0]        S_AXI_ARPROT;
  logic              S_AXI_ARVALID;
  logic              S_AXI_ARREADY;
  logic [DATA_W-1:0] S_AXI_RDATA;
  logic [1:0]        S_AXI_RRESP;
  logic              S_AXI_RVALID;
  logic              S_AXI_RREADY;

  logic [DATA_W-1:0] m_size_o;
  logic [DATA_W-1:0] n_size_o;
  logic [DATA_W-1:0] k_size_o;
  logic              start_o;
  logic              done_i;
  logic              busy_i;
  int                start_count;

  axi4lite_slave_lite_v1_0_S00_AXI #(
      .C_S_AXI_DATA_WIDTH(DATA_W),
      .C_S_AXI_ADDR_WIDTH(ADDR_W)
  ) dut (
      .m_size_o(m_size_o),
      .n_size_o(n_size_o),
      .k_size_o(k_size_o),
      .start_o(start_o),
      .done_i(done_i),
      .busy_i(busy_i),
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
      .S_AXI_RREADY(S_AXI_RREADY)
  );

  initial begin
    S_AXI_ACLK = 1'b0;
    forever #5 S_AXI_ACLK = ~S_AXI_ACLK;
  end

  always_ff @(posedge S_AXI_ACLK or negedge S_AXI_ARESETN) begin
    if (!S_AXI_ARESETN) begin
      start_count <= 0;
    end else if (start_o) begin
      start_count <= start_count + 1;
    end
  end

  task automatic tick;
    begin
      @(posedge S_AXI_ACLK);
      #1;
    end
  endtask

  task automatic drive_idle;
    begin
      S_AXI_AWADDR  = '0;
      S_AXI_AWPROT  = '0;
      S_AXI_AWVALID = 1'b0;
      S_AXI_WDATA   = '0;
      S_AXI_WSTRB   = '0;
      S_AXI_WVALID  = 1'b0;
      S_AXI_BREADY  = 1'b0;
      S_AXI_ARADDR  = '0;
      S_AXI_ARPROT  = '0;
      S_AXI_ARVALID = 1'b0;
      S_AXI_RREADY  = 1'b0;
      done_i        = 1'b0;
      busy_i        = 1'b0;
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

  task automatic check_word(input string name, input logic [DATA_W-1:0] got,
                            input logic [DATA_W-1:0] exp);
    begin
      if (got !== exp) begin
        $error("%s: got 0x%08x, expected 0x%08x", name, got, exp);
        $finish;
      end
    end
  endtask

  task automatic axi_write(input logic [ADDR_W-1:0] addr, input logic [DATA_W-1:0] data,
                           input logic [DATA_W/8-1:0] strb);
    bit aw_done;
    bit w_done;
    begin
      aw_done = 1'b0;
      w_done  = 1'b0;

      S_AXI_AWADDR  = addr;
      S_AXI_AWVALID = 1'b1;
      S_AXI_WDATA   = data;
      S_AXI_WSTRB   = strb;
      S_AXI_WVALID  = 1'b1;
      S_AXI_BREADY  = 1'b1;

      for (int cycle = 0; cycle < 16; cycle++) begin
        #1;
        aw_done |= (S_AXI_AWVALID && S_AXI_AWREADY);
        w_done  |= (S_AXI_WVALID && S_AXI_WREADY);
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
      S_AXI_WDATA  = '0;
      S_AXI_WSTRB  = '0;
    end
  endtask

  task automatic axi_read(input logic [ADDR_W-1:0] addr, output logic [DATA_W-1:0] data);
    bit ar_done;
    begin
      ar_done = 1'b0;
      data    = '0;

      S_AXI_ARADDR  = addr;
      S_AXI_ARVALID = 1'b1;
      S_AXI_RREADY  = 1'b1;

      for (int cycle = 0; cycle < 16; cycle++) begin
        #1;
        ar_done |= (S_AXI_ARVALID && S_AXI_ARREADY);
        if (S_AXI_RVALID) begin
          data = S_AXI_RDATA;
          check_word("read response", {30'd0, S_AXI_RRESP}, 32'd0);
          tick();
          S_AXI_ARVALID = 1'b0;
          S_AXI_RREADY  = 1'b0;
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

  initial begin
    logic [DATA_W-1:0] rd_data;
    int                prev_start_count;

    drive_idle();
    S_AXI_ARESETN = 1'b0;

    repeat (3) tick();
    check_word("reset m_size", m_size_o, 32'd0);
    check_word("reset n_size", n_size_o, 32'd0);
    check_word("reset k_size", k_size_o, 32'd0);
    check_bit("reset start", start_o, 1'b0);

    S_AXI_ARESETN = 1'b1;
    tick();

    axi_write(4'h4, 32'd256, 4'hf);
    axi_write(4'h8, 32'd128, 4'hf);
    axi_write(4'hc, 32'd64, 4'hf);

    check_word("m_size_o", m_size_o, 32'd256);
    check_word("n_size_o", n_size_o, 32'd128);
    check_word("k_size_o", k_size_o, 32'd64);

    axi_read(4'h4, rd_data);
    check_word("read m_size", rd_data, 32'd256);
    axi_read(4'h8, rd_data);
    check_word("read n_size", rd_data, 32'd128);
    axi_read(4'hc, rd_data);
    check_word("read k_size", rd_data, 32'd64);

    prev_start_count = start_count;
    axi_write(4'h0, 32'h1, 4'hf);
    if (start_count != prev_start_count + 1) begin
      $error("start pulse count: got %0d, expected %0d", start_count, prev_start_count + 1);
      $finish;
    end
    tick();
    check_bit("start pulse clears", start_o, 1'b0);

    busy_i = 1'b1;
    axi_read(4'h0, rd_data);
    check_word("busy status", rd_data, 32'h2);

    done_i = 1'b1;
    tick();
    done_i = 1'b0;
    busy_i = 1'b0;

    axi_read(4'h0, rd_data);
    check_word("done status", rd_data, 32'h1);

    axi_write(4'h0, 32'h2, 4'hf);
    axi_read(4'h0, rd_data);
    check_word("done clear status", rd_data, 32'h0);

    axi_write(4'h4, 32'h0000_abcd, 4'h3);
    check_word("partial m_size write", m_size_o, 32'h0000_abcd);

    $display("tb_axi4lite_slave_lite PASS");
    $finish;
  end
endmodule

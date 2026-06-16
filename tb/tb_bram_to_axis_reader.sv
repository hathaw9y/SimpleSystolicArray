module tb_bram_to_axis_reader;
  localparam int DATA_W = 32;
  localparam int ADDR_W = 8;
  localparam int LEN_W  = 8;

  logic              aclk_i;
  logic              aresetn_i;
  logic              start_i;
  logic [ADDR_W-1:0] base_addr_i;
  logic [ LEN_W-1:0] length_i;
  logic              busy_o;
  logic              done_o;
  logic              error_o;
  logic [DATA_W-1:0] m_axis_tdata_o;
  logic              m_axis_tvalid_o;
  logic              m_axis_tready_i;
  logic              m_axis_tlast_o;
  logic              bram_en_o;
  logic [ADDR_W-1:0] bram_addr_o;
  logic [DATA_W-1:0] bram_data_i;

  logic [DATA_W-1:0] bram_mem[256];

  bram_to_axis_reader #(
      .DATA_W(DATA_W),
      .ADDR_W(ADDR_W),
      .LEN_W (LEN_W)
  ) dut (
      .aclk_i(aclk_i),
      .aresetn_i(aresetn_i),
      .start_i(start_i),
      .base_addr_i(base_addr_i),
      .length_i(length_i),
      .busy_o(busy_o),
      .done_o(done_o),
      .error_o(error_o),
      .m_axis_tdata_o(m_axis_tdata_o),
      .m_axis_tvalid_o(m_axis_tvalid_o),
      .m_axis_tready_i(m_axis_tready_i),
      .m_axis_tlast_o(m_axis_tlast_o),
      .bram_en_o(bram_en_o),
      .bram_addr_o(bram_addr_o),
      .bram_data_i(bram_data_i)
  );

  initial begin
    aclk_i = 1'b0;
    forever #5 aclk_i = ~aclk_i;
  end

  always_ff @(posedge aclk_i or negedge aresetn_i) begin
    if (!aresetn_i) begin
      bram_data_i <= '0;
    end else if (bram_en_o) begin
      bram_data_i <= bram_mem[bram_addr_o];
    end
  end

  task automatic tick;
    begin
      @(posedge aclk_i);
      #1;
    end
  endtask

  task automatic drive_idle;
    begin
      start_i         = 1'b0;
      base_addr_i     = '0;
      length_i        = '0;
      m_axis_tready_i = 1'b0;
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

  task automatic check_vec(input string name, input logic [DATA_W-1:0] got,
                           input logic [DATA_W-1:0] exp);
    begin
      if (got !== exp) begin
        $error("%s: got 0x%08x, expected 0x%08x", name, got, exp);
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

  task automatic pulse_start(input logic [ADDR_W-1:0] base_addr,
                             input logic [LEN_W-1:0] length);
    begin
      start_i     = 1'b1;
      base_addr_i = base_addr;
      length_i    = length;
      tick();
      start_i = 1'b0;
    end
  endtask

  task automatic wait_valid(input logic [DATA_W-1:0] exp_data, input logic exp_last);
    bit seen;
    begin
      seen = 1'b0;
      for (int wait_cycle = 0; wait_cycle < 8; wait_cycle++) begin
        #1;
        if (m_axis_tvalid_o) begin
          check_vec("m_axis_tdata", m_axis_tdata_o, exp_data);
          check_bit("m_axis_tlast", m_axis_tlast_o, exp_last);
          seen = 1'b1;
          wait_cycle = 8;
        end else begin
          tick();
        end
      end

      if (!seen) begin
        $error("m_axis_tvalid_o did not assert");
        $finish;
      end
    end
  endtask

  task automatic accept_beat(input logic [DATA_W-1:0] exp_data, input logic exp_last);
    begin
      wait_valid(exp_data, exp_last);
      m_axis_tready_i = 1'b1;
      tick();
      m_axis_tready_i = 1'b0;
    end
  endtask

  initial begin
    drive_idle();
    aresetn_i = 1'b0;

    for (int i = 0; i < 256; i++) begin
      bram_mem[i] = 32'h1000_0000 + DATA_W'(i);
    end

    repeat (3) tick();
    check_bit("reset busy", busy_o, 1'b0);
    check_bit("reset done", done_o, 1'b0);
    check_bit("reset error", error_o, 1'b0);
    check_bit("reset tvalid", m_axis_tvalid_o, 1'b0);
    check_bit("reset bram_en", bram_en_o, 1'b0);

    aresetn_i = 1'b1;
    tick();

    pulse_start(ADDR_W'(8), LEN_W'(0));
    check_bit("zero length busy", busy_o, 1'b0);
    check_bit("zero length done", done_o, 1'b1);
    check_bit("zero length error", error_o, 1'b0);
    check_bit("zero length tvalid", m_axis_tvalid_o, 1'b0);
    check_bit("zero length bram_en", bram_en_o, 1'b0);
    tick();
    check_bit("done pulse clears after zero length", done_o, 1'b0);

    pulse_start(ADDR_W'(16), LEN_W'(4));
    check_bit("normal busy after start", busy_o, 1'b1);
    check_bit("normal no valid immediately", m_axis_tvalid_o, 1'b0);

    wait_valid(bram_mem[16], 1'b0);
    check_bit("hold valid under backpressure", m_axis_tvalid_o, 1'b1);
    check_vec("hold data under backpressure", m_axis_tdata_o, bram_mem[16]);
    repeat (3) begin
      tick();
      check_bit("still valid under backpressure", m_axis_tvalid_o, 1'b1);
      check_vec("still same data under backpressure", m_axis_tdata_o, bram_mem[16]);
      check_bit("no done before first accept", done_o, 1'b0);
    end

    m_axis_tready_i = 1'b1;
    tick();
    m_axis_tready_i = 1'b0;
    accept_beat(bram_mem[17], 1'b0);

    start_i     = 1'b1;
    base_addr_i = ADDR_W'(80);
    length_i    = LEN_W'(2);
    accept_beat(bram_mem[18], 1'b0);
    start_i = 1'b0;

    accept_beat(bram_mem[19], 1'b1);
    check_bit("normal done on last", done_o, 1'b1);
    check_bit("normal not busy after last", busy_o, 1'b0);
    check_bit("normal no error", error_o, 1'b0);
    tick();
    check_bit("normal done pulse clears", done_o, 1'b0);

    pulse_start(ADDR_W'(32), LEN_W'(1));
    accept_beat(bram_mem[32], 1'b1);
    check_bit("single beat done", done_o, 1'b1);
    check_bit("single beat not busy", busy_o, 1'b0);
    tick();

    check_bit("idle tvalid low", m_axis_tvalid_o, 1'b0);
    check_bit("idle bram_en low", bram_en_o, 1'b0);

    $display("tb_bram_to_axis_reader PASS");
    $finish;
  end
endmodule

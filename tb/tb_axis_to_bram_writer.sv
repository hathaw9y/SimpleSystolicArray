module tb_axis_to_bram_writer;
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
  logic [DATA_W-1:0] s_axis_tdata_i;
  logic              s_axis_tvalid_i;
  logic              s_axis_tready_o;
  logic              s_axis_tlast_i;
  logic              bram_en_o;
  logic              bram_we_o;
  logic [ADDR_W-1:0] bram_addr_o;
  logic [DATA_W-1:0] bram_data_o;

  axis_to_bram_writer #(
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
      .s_axis_tdata_i(s_axis_tdata_i),
      .s_axis_tvalid_i(s_axis_tvalid_i),
      .s_axis_tready_o(s_axis_tready_o),
      .s_axis_tlast_i(s_axis_tlast_i),
      .bram_en_o(bram_en_o),
      .bram_we_o(bram_we_o),
      .bram_addr_o(bram_addr_o),
      .bram_data_o(bram_data_o)
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
      start_i         = 1'b0;
      base_addr_i     = '0;
      length_i        = '0;
      s_axis_tdata_i  = '0;
      s_axis_tvalid_i = 1'b0;
      s_axis_tlast_i  = 1'b0;
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

  task automatic drive_beat(input logic [DATA_W-1:0] data, input logic tlast,
                            input logic [ADDR_W-1:0] exp_addr);
    begin
      s_axis_tdata_i  = data;
      s_axis_tvalid_i = 1'b1;
      s_axis_tlast_i  = tlast;
      #1;
      check_bit("tready during beat", s_axis_tready_o, 1'b1);
      check_bit("bram_en during beat", bram_en_o, 1'b1);
      check_bit("bram_we during beat", bram_we_o, 1'b1);
      check_addr("bram_addr during beat", bram_addr_o, exp_addr);
      check_vec("bram_data during beat", bram_data_o, data);
      tick();
      s_axis_tvalid_i = 1'b0;
      s_axis_tlast_i  = 1'b0;
      s_axis_tdata_i  = '0;
    end
  endtask

  initial begin
    drive_idle();
    aresetn_i = 1'b0;

    repeat (3) tick();
    check_bit("reset busy", busy_o, 1'b0);
    check_bit("reset done", done_o, 1'b0);
    check_bit("reset error", error_o, 1'b0);
    check_bit("reset tready", s_axis_tready_o, 1'b0);
    check_bit("reset bram_en", bram_en_o, 1'b0);
    check_bit("reset bram_we", bram_we_o, 1'b0);

    aresetn_i = 1'b1;
    tick();

    pulse_start(ADDR_W'(8), LEN_W'(0));
    check_bit("zero length busy", busy_o, 1'b0);
    check_bit("zero length done", done_o, 1'b1);
    check_bit("zero length error", error_o, 1'b0);
    check_bit("zero length tready", s_axis_tready_o, 1'b0);
    check_bit("zero length bram_en", bram_en_o, 1'b0);
    tick();
    check_bit("done pulse clears after zero length", done_o, 1'b0);

    pulse_start(ADDR_W'(16), LEN_W'(4));
    check_bit("normal busy after start", busy_o, 1'b1);
    check_bit("normal tready after start", s_axis_tready_o, 1'b1);
    check_bit("normal no write without valid", bram_en_o, 1'b0);

    tick();
    check_bit("valid gap keeps busy", busy_o, 1'b1);
    check_bit("valid gap no write", bram_en_o, 1'b0);

    drive_beat(32'h1111_0000, 1'b0, ADDR_W'(16));
    check_bit("beat0 not done", done_o, 1'b0);
    drive_beat(32'h2222_0001, 1'b0, ADDR_W'(17));

    start_i     = 1'b1;
    base_addr_i = ADDR_W'(80);
    length_i    = LEN_W'(2);
    drive_beat(32'h3333_0002, 1'b0, ADDR_W'(18));
    start_i = 1'b0;

    drive_beat(32'h4444_0003, 1'b1, ADDR_W'(19));
    check_bit("normal done on last", done_o, 1'b1);
    check_bit("normal not busy after last", busy_o, 1'b0);
    check_bit("normal no error", error_o, 1'b0);
    check_bit("normal tready after done", s_axis_tready_o, 1'b0);
    tick();
    check_bit("normal done pulse clears", done_o, 1'b0);

    pulse_start(ADDR_W'(32), LEN_W'(3));
    drive_beat(32'haaaa_0000, 1'b0, ADDR_W'(32));
    drive_beat(32'hbbbb_0001, 1'b1, ADDR_W'(33));
    check_bit("early tlast done", done_o, 1'b1);
    check_bit("early tlast stops busy", busy_o, 1'b0);
    check_bit("early tlast error", error_o, 1'b1);
    tick();

    pulse_start(ADDR_W'(48), LEN_W'(2));
    check_bit("new start clears previous error", error_o, 1'b0);
    drive_beat(32'hcccc_0000, 1'b0, ADDR_W'(48));
    drive_beat(32'hdddd_0001, 1'b0, ADDR_W'(49));
    check_bit("missing tlast done", done_o, 1'b1);
    check_bit("missing tlast stops busy", busy_o, 1'b0);
    check_bit("missing tlast error", error_o, 1'b1);
    tick();

    s_axis_tvalid_i = 1'b1;
    s_axis_tdata_i  = 32'heeee_eeee;
    s_axis_tlast_i  = 1'b1;
    #1;
    check_bit("idle tready low", s_axis_tready_o, 1'b0);
    check_bit("idle valid no bram_en", bram_en_o, 1'b0);
    tick();
    drive_idle();

    $display("tb_axis_to_bram_writer PASS");
    $finish;
  end
endmodule

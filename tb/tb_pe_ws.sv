module tb_pe_ws;
  localparam int ACT_W    = 8;
  localparam int WEIGHT_W = 8;
  localparam int ACC_W    = 32;
  localparam int ROWS     = 16;
  localparam int ROW_ID   = 8;
  localparam int ROW_ID_W = (ROWS <= 1) ? 1 : $clog2(ROWS);

  logic                       aclk_i;
  logic                       aresetn_i;
  logic                       weight_load_i;
  logic        [ROW_ID_W-1:0] row_id_i;
  logic                       act_valid_i;
  logic                       acc_valid_i;
  logic signed [   ACT_W-1:0] act_i;
  logic signed [WEIGHT_W-1:0] weight_i;
  logic signed [   ACC_W-1:0] acc_i;
  logic                       weight_load_o;
  logic        [ROW_ID_W-1:0] row_id_o;
  logic                       act_valid_o;
  logic                       acc_valid_o;
  logic signed [   ACT_W-1:0] act_o;
  logic signed [WEIGHT_W-1:0] weight_o;
  logic signed [   ACC_W-1:0] acc_o;

  pe_ws #(
      .ACT_W(ACT_W),
      .WEIGHT_W(WEIGHT_W),
      .ACC_W(ACC_W),
      .ROWS(ROWS),
      .ROW_ID(ROW_ID),
      .ROW_ID_W(ROW_ID_W)
  ) dut (
      .aclk_i(aclk_i),
      .aresetn_i(aresetn_i),
      .weight_load_i(weight_load_i),
      .row_id_i(row_id_i),
      .act_valid_i(act_valid_i),
      .acc_valid_i(acc_valid_i),
      .act_i(act_i),
      .weight_i(weight_i),
      .acc_i(acc_i),
      .weight_load_o(weight_load_o),
      .row_id_o(row_id_o),
      .act_valid_o(act_valid_o),
      .acc_valid_o(acc_valid_o),
      .act_o(act_o),
      .weight_o(weight_o),
      .acc_o(acc_o)
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

  task automatic check_bit(input string name, input logic got, input logic exp);
    begin
      if (got !== exp) begin
        $error("%s: got %0b, expected %0b", name, got, exp);
        $finish;
      end
    end
  endtask

  task automatic check_vec(
      input string name,
      input logic signed [ACC_W-1:0] got,
      input logic signed [ACC_W-1:0] exp
  );
    begin
      if (got !== exp) begin
        $error("%s: got %0d, expected %0d", name, got, exp);
        $finish;
      end
    end
  endtask

  initial begin
    aresetn_i      = 1'b0;
    weight_load_i = 1'b0;
    row_id_i       = '0;
    act_valid_i    = 1'b0;
    acc_valid_i    = 1'b0;
    act_i          = '0;
    weight_i       = '0;
    acc_i          = '0;

    repeat (3) tick();
    check_bit("reset weight_load_o", weight_load_o, 1'b0);
    check_bit("reset act_valid_o", act_valid_o, 1'b0);
    check_bit("reset acc_valid_o", acc_valid_o, 1'b0);
    check_vec("reset acc_o", acc_o, 32'sd0);

    aresetn_i = 1'b1;
    tick();

    weight_load_i = 1'b1;
    row_id_i       = 4'd7;
    weight_i       = 8'sd11;
    tick();
    check_bit("miss weight_load_o", weight_load_o, 1'b1);
    check_vec("miss row pass", row_id_o, 32'sd7);
    check_vec("miss weight pass", weight_o, 32'sd11);

    weight_load_i = 1'b0;
    row_id_i       = '0;
    weight_i       = '0;
    act_valid_i    = 1'b1;
    acc_valid_i    = 1'b1;
    act_i          = 8'sd2;
    acc_i          = 32'sd5;
    tick();
    check_vec("missed load keeps weight zero", acc_o, 32'sd5);
    check_bit("both valids assert acc_valid_o", acc_valid_o, 1'b1);

    weight_load_i = 1'b1;
    row_id_i       = 4'd8;
    weight_i       = -8'sd3;
    act_valid_i    = 1'b0;
    acc_valid_i    = 1'b0;
    act_i          = '0;
    acc_i          = '0;
    tick();
    check_bit("hit weight_load_o", weight_load_o, 1'b1);
    check_vec("hit row pass", row_id_o, 32'sd8);
    check_vec("hit weight pass", weight_o, -32'sd3);

    weight_load_i = 1'b0;
    row_id_i       = '0;
    weight_i       = '0;
    act_valid_i    = 1'b1;
    acc_valid_i    = 1'b1;
    act_i          = 8'sd4;
    acc_i          = 32'sd10;
    tick();
    check_vec("signed MAC", acc_o, -32'sd2);
    check_vec("act pass", act_o, 32'sd4);
    check_bit("act valid pass", act_valid_o, 1'b1);
    check_bit("acc valid after MAC", acc_valid_o, 1'b1);

    act_valid_i = 1'b0;
    acc_valid_i = 1'b1;
    acc_i       = 32'sd123;
    tick();
    check_vec("invalid MAC passes acc", acc_o, 32'sd123);
    check_bit("invalid MAC clears acc_valid_o", acc_valid_o, 1'b0);

    $display("tb_pe_ws PASS");
    $finish;
  end
endmodule

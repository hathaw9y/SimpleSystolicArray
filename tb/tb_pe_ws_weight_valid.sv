module tb_pe_ws_weight_valid;
  localparam int ACT_W    = 8;
  localparam int WEIGHT_W = 8;
  localparam int ACC_W    = 32;

  logic                       aclk_i;
  logic                       aresetn_i;
  logic                       act_valid_i;
  logic                       weight_valid_i;
  logic                       acc_valid_i;
  logic signed [   ACT_W-1:0] act_i;
  logic signed [WEIGHT_W-1:0] weight_i;
  logic signed [   ACC_W-1:0] acc_i;
  logic                       act_valid_o;
  logic                       acc_valid_o;
  logic signed [   ACT_W-1:0] act_o;
  logic signed [WEIGHT_W-1:0] weight_o;
  logic signed [   ACC_W-1:0] acc_o;

  pe_ws #(
      .ACT_W(ACT_W),
      .WEIGHT_W(WEIGHT_W),
      .ACC_W(ACC_W)
  ) dut (
      .aclk_i(aclk_i),
      .aresetn_i(aresetn_i),
      .act_valid_i(act_valid_i),
      .weight_valid_i(weight_valid_i),
      .acc_valid_i(acc_valid_i),
      .act_i(act_i),
      .weight_i(weight_i),
      .acc_i(acc_i),
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
    act_valid_i    = 1'b0;
    weight_valid_i = 1'b0;
    acc_valid_i    = 1'b0;
    act_i          = '0;
    weight_i       = '0;
    acc_i          = '0;

    repeat (3) tick();
    check_bit("reset act_valid_o", act_valid_o, 1'b0);
    check_bit("reset acc_valid_o", acc_valid_o, 1'b0);
    check_vec("reset acc_o", acc_o, 32'sd0);

    aresetn_i = 1'b1;
    tick();

    weight_valid_i = 1'b1;
    weight_i       = -8'sd3;
    tick();

    weight_valid_i = 1'b0;
    weight_i       = '0;
    act_valid_i    = 1'b1;
    acc_valid_i    = 1'b1;
    act_i          = 8'sd4;
    acc_i          = 32'sd10;
    tick();
    check_vec("signed MAC after weight load", acc_o, -32'sd2);
    check_bit("act valid pass", act_valid_o, 1'b1);
    check_bit("acc valid after MAC", acc_valid_o, 1'b1);
    check_vec("act pass", act_o, 32'sd4);

    weight_valid_i = 1'b1;
    weight_i       = 8'sd5;
    act_i          = 8'sd2;
    acc_i          = 32'sd1;
    tick();
    check_vec("MAC uses previous weight during load edge", acc_o, -32'sd5);

    weight_valid_i = 1'b0;
    weight_i       = '0;
    tick();
    check_vec("MAC uses updated weight next cycle", acc_o, 32'sd11);

    act_valid_i = 1'b0;
    acc_valid_i = 1'b1;
    acc_i       = 32'sd123;
    tick();
    check_vec("invalid act passes acc", acc_o, 32'sd123);
    check_bit("invalid act clears acc valid", acc_valid_o, 1'b0);

    $display("tb_pe_ws_weight_valid PASS");
    $finish;
  end
endmodule

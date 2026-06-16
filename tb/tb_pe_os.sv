module tb_pe_os;
  localparam int ACT_W    = 8;
  localparam int WEIGHT_W = 8;
  localparam int ACC_W    = 32;

  logic                aclk_i;
  logic                aresetn_i;
  logic                act_valid_i;
  logic                weight_valid_i;
  logic                acc_clear_i;
  logic [   ACT_W-1:0] act_i;
  logic [WEIGHT_W-1:0] weight_i;
  logic                act_valid_o;
  logic                weight_valid_o;
  logic                acc_clear_o;
  logic [   ACT_W-1:0] act_o;
  logic [WEIGHT_W-1:0] weight_o;
  logic [   ACC_W-1:0] acc_o;

  pe_os #(
      .ACT_W(ACT_W),
      .WEIGHT_W(WEIGHT_W),
      .ACC_W(ACC_W)
  ) dut (
      .aclk_i(aclk_i),
      .aresetn_i(aresetn_i),
      .act_valid_i(act_valid_i),
      .weight_valid_i(weight_valid_i),
      .acc_clear_i(acc_clear_i),
      .act_i(act_i),
      .weight_i(weight_i),
      .act_valid_o(act_valid_o),
      .weight_valid_o(weight_valid_o),
      .acc_clear_o(acc_clear_o),
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

  task automatic check_eq(
      input string name,
      input logic [ACC_W-1:0] got,
      input logic [ACC_W-1:0] exp
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
    acc_clear_i    = 1'b0;
    act_i          = '0;
    weight_i       = '0;

    repeat (3) tick();
    check_eq("reset acc_o", acc_o, 0);
    check_eq("reset act_valid_o", act_valid_o, 0);
    check_eq("reset weight_valid_o", weight_valid_o, 0);
    check_eq("reset acc_clear_o", acc_clear_o, 0);

    aresetn_i = 1'b1;
    tick();

    act_valid_i    = 1'b1;
    weight_valid_i = 1'b1;
    act_i          = 8'd3;
    weight_i       = 8'd4;
    tick();
    check_eq("first MAC acc_o", acc_o, 12);
    check_eq("first MAC act_o", act_o, 3);
    check_eq("first MAC weight_o", weight_o, 4);
    check_eq("first MAC act_valid_o", act_valid_o, 1);
    check_eq("first MAC weight_valid_o", weight_valid_o, 1);

    act_valid_i    = 1'b1;
    weight_valid_i = 1'b0;
    act_i          = 8'd9;
    weight_i       = 8'd9;
    tick();
    check_eq("one-sided valid holds acc_o", acc_o, 12);
    check_eq("one-sided valid act_o", act_o, 9);
    check_eq("one-sided valid weight_o", weight_o, 9);
    check_eq("one-sided valid weight_valid_o", weight_valid_o, 0);

    act_valid_i    = 1'b1;
    weight_valid_i = 1'b1;
    act_i          = 8'd5;
    weight_i       = 8'd6;
    tick();
    check_eq("second MAC acc_o", acc_o, 42);

    acc_clear_i = 1'b1;
    act_i       = 8'd7;
    weight_i    = 8'd8;
    tick();
    check_eq("clear wins over MAC acc_o", acc_o, 0);
    check_eq("clear propagates acc_clear_o", acc_clear_o, 1);

    acc_clear_i = 1'b0;
    act_i       = 8'd2;
    weight_i    = 8'd7;
    tick();
    check_eq("MAC after clear acc_o", acc_o, 14);
    check_eq("clear deasserts acc_clear_o", acc_clear_o, 0);

    $display("tb_pe_os PASS");
    $finish;
  end
endmodule

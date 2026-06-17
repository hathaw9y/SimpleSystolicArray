module tb_simple_dual_port_bram_model #(
    parameter int DATA_W = 128,
    parameter int ADDR_W = 9,
    parameter int DEPTH  = 512
) (
    input  logic              clka,
    input  logic              ena,
    input  logic [      0:0] wea,
    input  logic [ADDR_W-1:0] addra,
    input  logic [DATA_W-1:0] dina,
    input  logic              clkb,
    input  logic              enb,
    input  logic [ADDR_W-1:0] addrb,
    output logic [DATA_W-1:0] doutb
);

  logic [DATA_W-1:0] mem[DEPTH];

  initial begin
    for (int i = 0; i < DEPTH; i++) begin
      mem[i] = '0;
    end
  end

  always @(posedge clka) begin
    if (ena && wea[0]) begin
      mem[addra] <= dina;
    end
  end

  always @(posedge clkb) begin
    if (enb) begin
      doutb <= mem[addrb];
    end
  end

endmodule

module W128_D512_BLK_MEM (
    input  logic         clka,
    input  logic         ena,
    input  logic [  0:0] wea,
    input  logic [  8:0] addra,
    input  logic [127:0] dina,
    input  logic         clkb,
    input  logic         enb,
    input  logic [  8:0] addrb,
    output logic [127:0] doutb
);

  tb_simple_dual_port_bram_model #(
      .DATA_W(128),
      .ADDR_W(9),
      .DEPTH (512)
  ) u_model (
      .clka (clka),
      .ena  (ena),
      .wea  (wea),
      .addra(addra),
      .dina (dina),
      .clkb (clkb),
      .enb  (enb),
      .addrb(addrb),
      .doutb(doutb)
  );

endmodule

module W512_D512_BLK_MEM (
    input  logic         clka,
    input  logic         ena,
    input  logic [  0:0] wea,
    input  logic [  8:0] addra,
    input  logic [511:0] dina,
    input  logic         clkb,
    input  logic         enb,
    input  logic [  8:0] addrb,
    output logic [511:0] doutb
);

  tb_simple_dual_port_bram_model #(
      .DATA_W(512),
      .ADDR_W(9),
      .DEPTH (512)
  ) u_model (
      .clka (clka),
      .ena  (ena),
      .wea  (wea),
      .addra(addra),
      .dina (dina),
      .clkb (clkb),
      .enb  (enb),
      .addrb(addrb),
      .doutb(doutb)
  );

endmodule

module tb_simple_dual_port_bram_model #(
    parameter int DATA_W       = 128,
    parameter int ADDR_W       = 9,
    parameter int DEPTH        = 512,
    parameter int READ_LATENCY = 2
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

  localparam int VALID_LATENCY = (READ_LATENCY < 1) ? 1 : READ_LATENCY;

  logic [DATA_W-1:0] mem[DEPTH];
  logic [DATA_W-1:0] read_pipe[VALID_LATENCY];

  initial begin
    for (int i = 0; i < DEPTH; i++) begin
      mem[i] = '0;
    end
    for (int i = 0; i < VALID_LATENCY; i++) begin
      read_pipe[i] = '0;
    end
    doutb = '0;
  end

  always @(posedge clka) begin
    if (ena && wea[0]) begin
      mem[addra] <= dina;
    end
  end

  if (VALID_LATENCY == 1) begin : g_latency_1
    always @(posedge clkb) begin
      if (enb) begin
        doutb <= mem[addrb];
      end
    end
  end else begin : g_latency_n
    always @(posedge clkb) begin
      if (enb) begin
        read_pipe[0] <= mem[addrb];
      end
      for (int p = 1; p < VALID_LATENCY - 1; p++) begin
        read_pipe[p] <= read_pipe[p-1];
      end
      doutb <= read_pipe[VALID_LATENCY-2];
    end
  end

endmodule

module w128_d512_blk_mem (
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

module w512_d512_blk_mem (
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

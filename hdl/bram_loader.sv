module bram_loader #(
    parameter int ROWS         = 16,
    parameter int DATA_W       = 8,
    parameter int BRAM_W       = 128,
    parameter int ADDR_W       = 9,
    parameter int READ_LATENCY = 1
) (
    input  logic              aclk_i,
    input  logic              aresetn_i,
    input  logic              en_i,               // 읽기 요청
    input  logic [ADDR_W-1:0] addr_i,
    // BRAM 인터페이스
    output logic              bram_en_o,
    output logic [ADDR_W-1:0] bram_addr_o,
    input  logic [BRAM_W-1:0] bram_data_i,
    // 출력
    output logic [DATA_W-1:0] data_o     [ROWS],
    output logic              valid_o
);

  localparam int VALID_LATENCY = (READ_LATENCY < 1) ? 1 : READ_LATENCY;

  logic [VALID_LATENCY-1:0] valid_pipe_r;

  assign bram_en_o   = en_i;
  assign bram_addr_o = addr_i;
  assign valid_o = valid_pipe_r[VALID_LATENCY-1];

  // BMG Port B read latency에 맞춰 valid를 지연한다.
  always_ff @(posedge aclk_i) begin
    if (!aresetn_i) begin
      valid_pipe_r <= '0;
    end else begin
      valid_pipe_r[0] <= en_i;
      for (int p = 1; p < VALID_LATENCY; p++) begin
        valid_pipe_r[p] <= valid_pipe_r[p-1];
      end
    end
  end

  // 128bit unpack
  genvar i;
  generate
    for (i = 0; i < ROWS; i++) begin : g_unpack
      assign data_o[i] = bram_data_i[i*DATA_W+:DATA_W];
    end
  endgenerate

endmodule

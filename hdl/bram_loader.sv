module bram_loader #(
    parameter int ROWS   = 16,
    parameter int DATA_W = 8,
    parameter int BRAM_W = 128,
    parameter int ADDR_W = 9
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
    output logic              valid_o             // bram_en 1클락 지연
);

  assign bram_en_o   = en_i;
  assign bram_addr_o = addr_i;

  // valid: en_i 1클락 지연
  always_ff @(posedge aclk_i) begin
    if (!aresetn_i) valid_o <= 0;
    else valid_o <= en_i;
  end

  // 128bit unpack
  genvar i;
  generate
    for (i = 0; i < ROWS; i++) begin : g_unpack
      assign data_o[i] = bram_data_i[i*DATA_W+:DATA_W];
    end
  endgenerate

endmodule

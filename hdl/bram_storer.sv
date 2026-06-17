module bram_storer #(
    parameter int LANES  = 16,
    parameter int DATA_W = 32,   // ACC_W
    parameter int BRAM_W = LANES * DATA_W,
    parameter int ADDR_W = 9
) (
    input  logic                     aclk_i,
    input  logic                     aresetn_i,
    input  logic                     valid_i,             // 저장 요청
    input  logic        [ADDR_W-1:0] addr_i,              // 저장 주소
    input  logic signed [DATA_W-1:0] data_i      [LANES], // lane별 저장 데이터
    // BRAM 인터페이스
    output logic                     bram_en_o,
    output logic                     bram_we_o,
    output logic        [ADDR_W-1:0] bram_addr_o,
    output logic        [BRAM_W-1:0] bram_data_o
);

  assign bram_en_o   = valid_i;
  assign bram_we_o   = valid_i;
  assign bram_addr_o = addr_i;

  // LANES개 DATA_W bit를 한 BRAM word로 pack한다.
  genvar i;
  generate
    for (i = 0; i < LANES; i++) begin : g_pack
      assign bram_data_o[i*DATA_W+:DATA_W] = data_i[i];
    end
  endgenerate

endmodule

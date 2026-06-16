module systolic_array_top_os #(
    parameter int ROWS     = 16,
    parameter int COLS     = 16,
    parameter int ACT_W    = 8,
    parameter int WEIGHT_W = 8,
    parameter int ACC_W    = 32,
    parameter int ADDR_W   = 10,
    parameter int LEN_W    = 16,
    parameter logic [ADDR_W-1:0] ACT_BASE_ADDR    = '0,
    parameter logic [ADDR_W-1:0] WEIGHT_BASE_ADDR = '0,
    parameter logic [ADDR_W-1:0] ACC_BASE_ADDR    = '0
) (
    input logic S_AXI_ACLK,
    input logic S_AXI_ARESETN,

    input  logic [3:0]  S_AXI_AWADDR,
    input  logic [2:0]  S_AXI_AWPROT,
    input  logic        S_AXI_AWVALID,
    output logic        S_AXI_AWREADY,
    input  logic [31:0] S_AXI_WDATA,
    input  logic [3:0]  S_AXI_WSTRB,
    input  logic        S_AXI_WVALID,
    output logic        S_AXI_WREADY,
    output logic [1:0]  S_AXI_BRESP,
    output logic        S_AXI_BVALID,
    input  logic        S_AXI_BREADY,
    input  logic [3:0]  S_AXI_ARADDR,
    input  logic [2:0]  S_AXI_ARPROT,
    input  logic        S_AXI_ARVALID,
    output logic        S_AXI_ARREADY,
    output logic [31:0] S_AXI_RDATA,
    output logic [1:0]  S_AXI_RRESP,
    output logic        S_AXI_RVALID,
    input  logic        S_AXI_RREADY,

    input  logic                       act_load_start_i,
    input  logic        [  ADDR_W-1:0] act_load_base_addr_i,
    input  logic        [   LEN_W-1:0] act_load_length_i,
    output logic                       act_load_busy_o,
    output logic                       act_load_done_o,
    output logic                       act_load_error_o,
    input  logic        [ROWS*ACT_W-1:0] s_axis_act_tdata_i,
    input  logic                       s_axis_act_tvalid_i,
    output logic                       s_axis_act_tready_o,
    input  logic                       s_axis_act_tlast_i,

    input  logic                       weight_load_start_i,
    input  logic        [  ADDR_W-1:0] weight_load_base_addr_i,
    input  logic        [   LEN_W-1:0] weight_load_length_i,
    output logic                       weight_load_busy_o,
    output logic                       weight_load_done_o,
    output logic                       weight_load_error_o,
    input  logic        [COLS*WEIGHT_W-1:0] s_axis_weight_tdata_i,
    input  logic                       s_axis_weight_tvalid_i,
    output logic                       s_axis_weight_tready_o,
    input  logic                       s_axis_weight_tlast_i,

    input  logic                       result_store_start_i,
    input  logic        [  ADDR_W-1:0] result_store_base_addr_i,
    input  logic        [   LEN_W-1:0] result_store_length_i,
    output logic                       result_store_busy_o,
    output logic                       result_store_done_o,
    output logic                       result_store_error_o,
    output logic        [ROWS*ACC_W-1:0] m_axis_result_tdata_o,
    output logic                       m_axis_result_tvalid_o,
    input  logic                       m_axis_result_tready_i,
    output logic                       m_axis_result_tlast_o,

    output logic                       act_wr_bram_en_o,
    output logic                       act_wr_bram_we_o,
    output logic        [  ADDR_W-1:0] act_wr_bram_addr_o,
    output logic        [ROWS*ACT_W-1:0] act_wr_bram_data_o,
    output logic                       act_rd_bram_en_o,
    output logic        [  ADDR_W-1:0] act_rd_bram_addr_o,
    input  logic        [ROWS*ACT_W-1:0] act_rd_bram_data_i,

    output logic                       weight_wr_bram_en_o,
    output logic                       weight_wr_bram_we_o,
    output logic        [  ADDR_W-1:0] weight_wr_bram_addr_o,
    output logic        [COLS*WEIGHT_W-1:0] weight_wr_bram_data_o,
    output logic                       weight_rd_bram_en_o,
    output logic        [  ADDR_W-1:0] weight_rd_bram_addr_o,
    input  logic        [COLS*WEIGHT_W-1:0] weight_rd_bram_data_i,

    output logic                       acc_wr_bram_en_o,
    output logic                       acc_wr_bram_we_o,
    output logic        [  ADDR_W-1:0] acc_wr_bram_addr_o,
    output logic        [ROWS*ACC_W-1:0] acc_wr_bram_data_o,
    output logic                       acc_rd_bram_en_o,
    output logic        [  ADDR_W-1:0] acc_rd_bram_addr_o,
    input  logic        [ROWS*ACC_W-1:0] acc_rd_bram_data_i
);

  localparam int ACT_BRAM_W    = ROWS * ACT_W;
  localparam int WEIGHT_BRAM_W = COLS * WEIGHT_W;
  localparam int ACC_BRAM_W    = ROWS * ACC_W;

  logic [31:0]       ctrl_m_size_w;
  logic [31:0]       ctrl_n_size_w;
  logic [31:0]       ctrl_k_size_w;
  logic              ctrl_start_w;
  logic              engine_start_w;
  logic              engine_done_w;
  logic              engine_busy_r;

  assign engine_start_w = ctrl_start_w && !engine_busy_r;

  always_ff @(posedge S_AXI_ACLK) begin
    if (!S_AXI_ARESETN) begin
      engine_busy_r <= 1'b0;
    end else begin
      if (engine_start_w) begin
        engine_busy_r <= 1'b1;
      end else if (engine_done_w) begin
        engine_busy_r <= 1'b0;
      end
    end
  end

  axi4lite_slave_lite_v1_0_S00_AXI #(
      .C_S_AXI_DATA_WIDTH(32),
      .C_S_AXI_ADDR_WIDTH(4)
  ) u_ctrl (
      .m_size_o     (ctrl_m_size_w),
      .n_size_o     (ctrl_n_size_w),
      .k_size_o     (ctrl_k_size_w),
      .start_o      (ctrl_start_w),
      .done_i       (engine_done_w),
      .busy_i       (engine_busy_r),
      .S_AXI_ACLK   (S_AXI_ACLK),
      .S_AXI_ARESETN(S_AXI_ARESETN),
      .S_AXI_AWADDR (S_AXI_AWADDR),
      .S_AXI_AWPROT (S_AXI_AWPROT),
      .S_AXI_AWVALID(S_AXI_AWVALID),
      .S_AXI_AWREADY(S_AXI_AWREADY),
      .S_AXI_WDATA  (S_AXI_WDATA),
      .S_AXI_WSTRB  (S_AXI_WSTRB),
      .S_AXI_WVALID (S_AXI_WVALID),
      .S_AXI_WREADY (S_AXI_WREADY),
      .S_AXI_BRESP  (S_AXI_BRESP),
      .S_AXI_BVALID (S_AXI_BVALID),
      .S_AXI_BREADY (S_AXI_BREADY),
      .S_AXI_ARADDR (S_AXI_ARADDR),
      .S_AXI_ARPROT (S_AXI_ARPROT),
      .S_AXI_ARVALID(S_AXI_ARVALID),
      .S_AXI_ARREADY(S_AXI_ARREADY),
      .S_AXI_RDATA  (S_AXI_RDATA),
      .S_AXI_RRESP  (S_AXI_RRESP),
      .S_AXI_RVALID (S_AXI_RVALID),
      .S_AXI_RREADY (S_AXI_RREADY)
  );

  axis_to_bram_writer #(
      .DATA_W(ACT_BRAM_W),
      .ADDR_W(ADDR_W),
      .LEN_W (LEN_W)
  ) u_act_writer (
      .aclk_i         (S_AXI_ACLK),
      .aresetn_i      (S_AXI_ARESETN),
      .start_i        (act_load_start_i),
      .base_addr_i    (act_load_base_addr_i),
      .length_i       (act_load_length_i),
      .busy_o         (act_load_busy_o),
      .done_o         (act_load_done_o),
      .error_o        (act_load_error_o),
      .s_axis_tdata_i (s_axis_act_tdata_i),
      .s_axis_tvalid_i(s_axis_act_tvalid_i),
      .s_axis_tready_o(s_axis_act_tready_o),
      .s_axis_tlast_i (s_axis_act_tlast_i),
      .bram_en_o      (act_wr_bram_en_o),
      .bram_we_o      (act_wr_bram_we_o),
      .bram_addr_o    (act_wr_bram_addr_o),
      .bram_data_o    (act_wr_bram_data_o)
  );

  axis_to_bram_writer #(
      .DATA_W(WEIGHT_BRAM_W),
      .ADDR_W(ADDR_W),
      .LEN_W (LEN_W)
  ) u_weight_writer (
      .aclk_i         (S_AXI_ACLK),
      .aresetn_i      (S_AXI_ARESETN),
      .start_i        (weight_load_start_i),
      .base_addr_i    (weight_load_base_addr_i),
      .length_i       (weight_load_length_i),
      .busy_o         (weight_load_busy_o),
      .done_o         (weight_load_done_o),
      .error_o        (weight_load_error_o),
      .s_axis_tdata_i (s_axis_weight_tdata_i),
      .s_axis_tvalid_i(s_axis_weight_tvalid_i),
      .s_axis_tready_o(s_axis_weight_tready_o),
      .s_axis_tlast_i (s_axis_weight_tlast_i),
      .bram_en_o      (weight_wr_bram_en_o),
      .bram_we_o      (weight_wr_bram_we_o),
      .bram_addr_o    (weight_wr_bram_addr_o),
      .bram_data_o    (weight_wr_bram_data_o)
  );

  systolic_array_engine_os #(
      .ROWS    (ROWS),
      .COLS    (COLS),
      .ACT_W   (ACT_W),
      .WEIGHT_W(WEIGHT_W),
      .ACC_W   (ACC_W),
      .ADDR_W  (ADDR_W)
  ) u_engine (
      .aclk_i            (S_AXI_ACLK),
      .aresetn_i         (S_AXI_ARESETN),
      .start_i           (engine_start_w),
      .m_size_i          (ctrl_m_size_w[ADDR_W-1:0]),
      .n_size_i          (ctrl_n_size_w[ADDR_W-1:0]),
      .k_size_i          (ctrl_k_size_w[ADDR_W-1:0]),
      .act_base_addr_i   (ACT_BASE_ADDR),
      .weight_base_addr_i(WEIGHT_BASE_ADDR),
      .acc_base_addr_i   (ACC_BASE_ADDR),
      .act_bram_en_o     (act_rd_bram_en_o),
      .act_bram_addr_o   (act_rd_bram_addr_o),
      .act_bram_data_i   (act_rd_bram_data_i),
      .weight_bram_en_o  (weight_rd_bram_en_o),
      .weight_bram_addr_o(weight_rd_bram_addr_o),
      .weight_bram_data_i(weight_rd_bram_data_i),
      .acc_bram_en_o     (acc_wr_bram_en_o),
      .acc_bram_we_o     (acc_wr_bram_we_o),
      .acc_bram_addr_o   (acc_wr_bram_addr_o),
      .acc_bram_data_o   (acc_wr_bram_data_o),
      .done_o            (engine_done_w)
  );

  bram_to_axis_reader #(
      .DATA_W(ACC_BRAM_W),
      .ADDR_W(ADDR_W),
      .LEN_W (LEN_W)
  ) u_result_reader (
      .aclk_i         (S_AXI_ACLK),
      .aresetn_i      (S_AXI_ARESETN),
      .start_i        (result_store_start_i),
      .base_addr_i    (result_store_base_addr_i),
      .length_i       (result_store_length_i),
      .busy_o         (result_store_busy_o),
      .done_o         (result_store_done_o),
      .error_o        (result_store_error_o),
      .m_axis_tdata_o (m_axis_result_tdata_o),
      .m_axis_tvalid_o(m_axis_result_tvalid_o),
      .m_axis_tready_i(m_axis_result_tready_i),
      .m_axis_tlast_o (m_axis_result_tlast_o),
      .bram_en_o      (acc_rd_bram_en_o),
      .bram_addr_o    (acc_rd_bram_addr_o),
      .bram_data_i    (acc_rd_bram_data_i)
  );

endmodule

module systolic_array_top_ws #(
    parameter int                ROWS             = 16,
    parameter int                COLS             = 16,
    parameter int                ACT_W            = 8,
    parameter int                WEIGHT_W         = 8,
    parameter int                ACC_W            = 32,
    parameter int                ADDR_W           = 9,
    parameter int                LEN_W            = 16,
    parameter logic [ADDR_W-1:0] ACT_BASE_ADDR    = '0,
    parameter logic [ADDR_W-1:0] WEIGHT_BASE_ADDR = '0,
    parameter logic [ADDR_W-1:0] ACC_BASE_ADDR    = '0
) (
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 S_AXI_ACLK CLK" *)
    (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF S_AXI:S_AXIS_ACT:S_AXIS_WEIGHT:M_AXIS_RESULT:ACT_BRAM_PORTA:ACT_BRAM_PORTB:WEIGHT_BRAM_PORTA:WEIGHT_BRAM_PORTB:ACC_BRAM_PORTA:ACC_BRAM_PORTB, ASSOCIATED_RESET S_AXI_ARESETN" *)
    input logic S_AXI_ACLK,
    (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 S_AXI_ARESETN RST" *)
    (* X_INTERFACE_PARAMETER = "POLARITY ACTIVE_LOW" *)
    input logic S_AXI_ARESETN,

    input  logic [ 3:0] S_AXI_AWADDR,
    input  logic [ 2:0] S_AXI_AWPROT,
    input  logic        S_AXI_AWVALID,
    output logic        S_AXI_AWREADY,
    input  logic [31:0] S_AXI_WDATA,
    input  logic [ 3:0] S_AXI_WSTRB,
    input  logic        S_AXI_WVALID,
    output logic        S_AXI_WREADY,
    output logic [ 1:0] S_AXI_BRESP,
    output logic        S_AXI_BVALID,
    input  logic        S_AXI_BREADY,
    input  logic [ 3:0] S_AXI_ARADDR,
    input  logic [ 2:0] S_AXI_ARPROT,
    input  logic        S_AXI_ARVALID,
    output logic        S_AXI_ARREADY,
    output logic [31:0] S_AXI_RDATA,
    output logic [ 1:0] S_AXI_RRESP,
    output logic        S_AXI_RVALID,
    input  logic        S_AXI_RREADY,

    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 S_AXIS_ACT TDATA" *)
    input  logic [ROWS*ACT_W-1:0] s_axis_act_tdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 S_AXIS_ACT TVALID" *)
    input  logic                  s_axis_act_tvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 S_AXIS_ACT TREADY" *)
    output logic                  s_axis_act_tready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 S_AXIS_ACT TLAST" *)
    input  logic                  s_axis_act_tlast,

    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 S_AXIS_WEIGHT TDATA" *)
    input  logic [COLS*WEIGHT_W-1:0] s_axis_weight_tdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 S_AXIS_WEIGHT TVALID" *)
    input  logic                     s_axis_weight_tvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 S_AXIS_WEIGHT TREADY" *)
    output logic                     s_axis_weight_tready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 S_AXIS_WEIGHT TLAST" *)
    input  logic                     s_axis_weight_tlast,

    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 M_AXIS_RESULT TDATA" *)
    output logic [COLS*ACC_W-1:0] m_axis_result_tdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 M_AXIS_RESULT TVALID" *)
    output logic                  m_axis_result_tvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 M_AXIS_RESULT TREADY" *)
    input  logic                  m_axis_result_tready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 M_AXIS_RESULT TLAST" *)
    output logic                  m_axis_result_tlast,

    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 ACT_BRAM_PORTA CLK" *)
    output logic                  act_bram_clka,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 ACT_BRAM_PORTA EN" *)
    output logic                  act_bram_ena,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 ACT_BRAM_PORTA WE" *)
    output logic [          0:0] act_bram_wea,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 ACT_BRAM_PORTA ADDR" *)
    output logic [    ADDR_W-1:0] act_bram_addra,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 ACT_BRAM_PORTA DIN" *)
    output logic [ROWS*ACT_W-1:0] act_bram_dina,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 ACT_BRAM_PORTB CLK" *)
    output logic                  act_bram_clkb,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 ACT_BRAM_PORTB EN" *)
    output logic                  act_bram_enb,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 ACT_BRAM_PORTB ADDR" *)
    output logic [    ADDR_W-1:0] act_bram_addrb,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 ACT_BRAM_PORTB DOUT" *)
    input  logic [ROWS*ACT_W-1:0] act_bram_doutb,

    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 WEIGHT_BRAM_PORTA CLK" *)
    output logic                     weight_bram_clka,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 WEIGHT_BRAM_PORTA EN" *)
    output logic                     weight_bram_ena,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 WEIGHT_BRAM_PORTA WE" *)
    output logic [             0:0] weight_bram_wea,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 WEIGHT_BRAM_PORTA ADDR" *)
    output logic [       ADDR_W-1:0] weight_bram_addra,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 WEIGHT_BRAM_PORTA DIN" *)
    output logic [COLS*WEIGHT_W-1:0] weight_bram_dina,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 WEIGHT_BRAM_PORTB CLK" *)
    output logic                     weight_bram_clkb,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 WEIGHT_BRAM_PORTB EN" *)
    output logic                     weight_bram_enb,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 WEIGHT_BRAM_PORTB ADDR" *)
    output logic [       ADDR_W-1:0] weight_bram_addrb,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 WEIGHT_BRAM_PORTB DOUT" *)
    input  logic [COLS*WEIGHT_W-1:0] weight_bram_doutb,

    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 ACC_BRAM_PORTA CLK" *)
    output logic                  acc_bram_clka,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 ACC_BRAM_PORTA EN" *)
    output logic                  acc_bram_ena,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 ACC_BRAM_PORTA WE" *)
    output logic [          0:0] acc_bram_wea,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 ACC_BRAM_PORTA ADDR" *)
    output logic [    ADDR_W-1:0] acc_bram_addra,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 ACC_BRAM_PORTA DIN" *)
    output logic [COLS*ACC_W-1:0] acc_bram_dina,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 ACC_BRAM_PORTB CLK" *)
    output logic                  acc_bram_clkb,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 ACC_BRAM_PORTB EN" *)
    output logic                  acc_bram_enb,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 ACC_BRAM_PORTB ADDR" *)
    output logic [    ADDR_W-1:0] acc_bram_addrb,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 ACC_BRAM_PORTB DOUT" *)
    input  logic [COLS*ACC_W-1:0] acc_bram_doutb
);

  localparam int ACT_BRAM_W = ROWS * ACT_W;
  localparam int WEIGHT_BRAM_W = COLS * WEIGHT_W;
  localparam int ACC_BRAM_W = COLS * ACC_W;

  assign act_bram_clka = S_AXI_ACLK;
  assign act_bram_clkb = S_AXI_ACLK;
  assign weight_bram_clka = S_AXI_ACLK;
  assign weight_bram_clkb = S_AXI_ACLK;
  assign acc_bram_clka = S_AXI_ACLK;
  assign acc_bram_clkb = S_AXI_ACLK;

  logic [      31:0] ctrl_m_size_w;
  logic [      31:0] ctrl_n_size_w;
  logic [      31:0] ctrl_k_size_w;
  logic              ctrl_start_w;
  logic              ctrl_clear_w;
  logic              controller_busy_w;
  logic              controller_done_w;
  logic              controller_error_w;
  logic [       3:0] controller_state_w;

  logic              act_load_start_w;
  logic [ADDR_W-1:0] act_load_base_addr_w;
  logic [ LEN_W-1:0] act_load_length_w;
  logic              act_load_busy_w;
  logic              act_load_done_w;
  logic              act_load_error_w;

  logic              weight_load_start_w;
  logic [ADDR_W-1:0] weight_load_base_addr_w;
  logic [ LEN_W-1:0] weight_load_length_w;
  logic              weight_load_busy_w;
  logic              weight_load_done_w;
  logic              weight_load_error_w;

  logic              engine_start_w;
  logic [ADDR_W-1:0] engine_m_size_w;
  logic [ADDR_W-1:0] engine_n_size_w;
  logic [ADDR_W-1:0] engine_k_size_w;
  logic [ADDR_W-1:0] engine_act_base_addr_w;
  logic [ADDR_W-1:0] engine_weight_base_addr_w;
  logic [ADDR_W-1:0] engine_acc_base_addr_w;
  logic              engine_done_w;

  logic              result_store_start_w;
  logic [ADDR_W-1:0] result_store_base_addr_w;
  logic [ LEN_W-1:0] result_store_length_w;
  logic              result_store_busy_w;
  logic              result_store_done_w;
  logic              result_store_error_w;
  logic              engine_acc_rd_bram_en_w;
  logic [ADDR_W-1:0] engine_acc_rd_bram_addr_w;
  logic              result_acc_rd_bram_en_w;
  logic [ADDR_W-1:0] result_acc_rd_bram_addr_w;

  assign acc_bram_enb = result_store_busy_w ? result_acc_rd_bram_en_w : engine_acc_rd_bram_en_w;
  assign acc_bram_addrb = result_store_busy_w ? result_acc_rd_bram_addr_w : engine_acc_rd_bram_addr_w;

  axi4lite_slave_lite_v1_0_S00_AXI #(
      .C_S_AXI_DATA_WIDTH(32),
      .C_S_AXI_ADDR_WIDTH(4)
  ) u_ctrl (
      .m_size_o     (ctrl_m_size_w),
      .n_size_o     (ctrl_n_size_w),
      .k_size_o     (ctrl_k_size_w),
      .start_o      (ctrl_start_w),
      .clear_o      (ctrl_clear_w),
      .done_i       (controller_done_w),
      .busy_i       (controller_busy_w),
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

  systolic_array_controller_ws #(
      .ROWS            (ROWS),
      .COLS            (COLS),
      .ADDR_W          (ADDR_W),
      .LEN_W           (LEN_W),
      .ACT_BASE_ADDR   (ACT_BASE_ADDR),
      .WEIGHT_BASE_ADDR(WEIGHT_BASE_ADDR),
      .ACC_BASE_ADDR   (ACC_BASE_ADDR)
  ) u_controller (
      .aclk_i                   (S_AXI_ACLK),
      .aresetn_i                (S_AXI_ARESETN),
      .start_i                  (ctrl_start_w),
      .clear_i                  (ctrl_clear_w),
      .busy_o                   (controller_busy_w),
      .done_o                   (controller_done_w),
      .error_o                  (controller_error_w),
      .state_o                  (controller_state_w),
      .m_size_i                 (ctrl_m_size_w[ADDR_W-1:0]),
      .n_size_i                 (ctrl_n_size_w[ADDR_W-1:0]),
      .k_size_i                 (ctrl_k_size_w[ADDR_W-1:0]),
      .act_load_start_o         (act_load_start_w),
      .act_load_base_addr_o     (act_load_base_addr_w),
      .act_load_length_o        (act_load_length_w),
      .act_load_done_i          (act_load_done_w),
      .act_load_error_i         (act_load_error_w),
      .weight_load_start_o      (weight_load_start_w),
      .weight_load_base_addr_o  (weight_load_base_addr_w),
      .weight_load_length_o     (weight_load_length_w),
      .weight_load_done_i       (weight_load_done_w),
      .weight_load_error_i      (weight_load_error_w),
      .engine_start_o           (engine_start_w),
      .engine_m_size_o          (engine_m_size_w),
      .engine_n_size_o          (engine_n_size_w),
      .engine_k_size_o          (engine_k_size_w),
      .engine_act_base_addr_o   (engine_act_base_addr_w),
      .engine_weight_base_addr_o(engine_weight_base_addr_w),
      .engine_acc_base_addr_o   (engine_acc_base_addr_w),
      .engine_done_i            (engine_done_w),
      .result_store_start_o     (result_store_start_w),
      .result_store_base_addr_o (result_store_base_addr_w),
      .result_store_length_o    (result_store_length_w),
      .result_store_done_i      (result_store_done_w),
      .result_store_error_i     (result_store_error_w)
  );

  axis_to_bram_writer #(
      .DATA_W(ACT_BRAM_W),
      .ADDR_W(ADDR_W),
      .LEN_W (LEN_W)
  ) u_act_writer (
      .aclk_i         (S_AXI_ACLK),
      .aresetn_i      (S_AXI_ARESETN),
      .start_i        (act_load_start_w),
      .base_addr_i    (act_load_base_addr_w),
      .length_i       (act_load_length_w),
      .busy_o         (act_load_busy_w),
      .done_o         (act_load_done_w),
      .error_o        (act_load_error_w),
      .s_axis_tdata_i (s_axis_act_tdata),
      .s_axis_tvalid_i(s_axis_act_tvalid),
      .s_axis_tready_o(s_axis_act_tready),
      .s_axis_tlast_i (s_axis_act_tlast),
      .bram_en_o      (act_bram_ena),
      .bram_we_o      (act_bram_wea[0]),
      .bram_addr_o    (act_bram_addra),
      .bram_data_o    (act_bram_dina)
  );

  axis_to_bram_writer #(
      .DATA_W(WEIGHT_BRAM_W),
      .ADDR_W(ADDR_W),
      .LEN_W (LEN_W)
  ) u_weight_writer (
      .aclk_i         (S_AXI_ACLK),
      .aresetn_i      (S_AXI_ARESETN),
      .start_i        (weight_load_start_w),
      .base_addr_i    (weight_load_base_addr_w),
      .length_i       (weight_load_length_w),
      .busy_o         (weight_load_busy_w),
      .done_o         (weight_load_done_w),
      .error_o        (weight_load_error_w),
      .s_axis_tdata_i (s_axis_weight_tdata),
      .s_axis_tvalid_i(s_axis_weight_tvalid),
      .s_axis_tready_o(s_axis_weight_tready),
      .s_axis_tlast_i (s_axis_weight_tlast),
      .bram_en_o      (weight_bram_ena),
      .bram_we_o      (weight_bram_wea[0]),
      .bram_addr_o    (weight_bram_addra),
      .bram_data_o    (weight_bram_dina)
  );

  systolic_array_engine_ws #(
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
      .m_size_i          (engine_m_size_w),
      .n_size_i          (engine_n_size_w),
      .k_size_i          (engine_k_size_w),
      .act_base_addr_i   (engine_act_base_addr_w),
      .weight_base_addr_i(engine_weight_base_addr_w),
      .acc_base_addr_i   (engine_acc_base_addr_w),
      .act_bram_en_o     (act_bram_enb),
      .act_bram_addr_o   (act_bram_addrb),
      .act_bram_data_i   (act_bram_doutb),
      .weight_bram_en_o  (weight_bram_enb),
      .weight_bram_addr_o(weight_bram_addrb),
      .weight_bram_data_i(weight_bram_doutb),
      .acc_rd_bram_en_o  (engine_acc_rd_bram_en_w),
      .acc_rd_bram_addr_o(engine_acc_rd_bram_addr_w),
      .acc_rd_bram_data_i(acc_bram_doutb),
      .acc_wr_bram_en_o  (acc_bram_ena),
      .acc_wr_bram_we_o  (acc_bram_wea[0]),
      .acc_wr_bram_addr_o(acc_bram_addra),
      .acc_wr_bram_data_o(acc_bram_dina),
      .done_o            (engine_done_w)
  );

  bram_to_axis_reader #(
      .DATA_W(ACC_BRAM_W),
      .ADDR_W(ADDR_W),
      .LEN_W (LEN_W)
  ) u_result_reader (
      .aclk_i         (S_AXI_ACLK),
      .aresetn_i      (S_AXI_ARESETN),
      .start_i        (result_store_start_w),
      .base_addr_i    (result_store_base_addr_w),
      .length_i       (result_store_length_w),
      .busy_o         (result_store_busy_w),
      .done_o         (result_store_done_w),
      .error_o        (result_store_error_w),
      .m_axis_tdata_o (m_axis_result_tdata),
      .m_axis_tvalid_o(m_axis_result_tvalid),
      .m_axis_tready_i(m_axis_result_tready),
      .m_axis_tlast_o (m_axis_result_tlast),
      .bram_en_o      (result_acc_rd_bram_en_w),
      .bram_addr_o    (result_acc_rd_bram_addr_w),
      .bram_data_i    (acc_bram_doutb)
  );

endmodule

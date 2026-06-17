module systolic_array_engine_ws #(
    parameter int ROWS     = 16,
    parameter int COLS     = 16,
    parameter int ACT_W    = 8,
    parameter int WEIGHT_W = 8,
    parameter int ACC_W    = 32,
    parameter int ADDR_W = 9
) (
    input  logic                       aclk_i,
    input  logic                       aresetn_i,
    input  logic                       start_i,
    input  logic        [  ADDR_W-1:0] m_size_i,
    input  logic        [  ADDR_W-1:0] n_size_i,
    input  logic        [  ADDR_W-1:0] k_size_i,
    input  logic        [  ADDR_W-1:0] act_base_addr_i,
    input  logic        [  ADDR_W-1:0] weight_base_addr_i,
    input  logic        [  ADDR_W-1:0] acc_base_addr_i,
    output logic                       act_bram_en_o,
    output logic        [  ADDR_W-1:0] act_bram_addr_o,
    input  logic        [ROWS*ACT_W-1:0] act_bram_data_i,
    output logic                       weight_bram_en_o,
    output logic        [  ADDR_W-1:0] weight_bram_addr_o,
    input  logic        [COLS*WEIGHT_W-1:0] weight_bram_data_i,
    output logic                       acc_rd_bram_en_o,
    output logic        [  ADDR_W-1:0] acc_rd_bram_addr_o,
    input  logic        [COLS*ACC_W-1:0] acc_rd_bram_data_i,
    output logic                       acc_wr_bram_en_o,
    output logic                       acc_wr_bram_we_o,
    output logic        [  ADDR_W-1:0] acc_wr_bram_addr_o,
    output logic        [COLS*ACC_W-1:0] acc_wr_bram_data_o,
    output logic                       done_o
);

  logic                       act_loader_en_w;
  logic        [  ADDR_W-1:0] act_loader_addr_w;
  logic        [   ACT_W-1:0] act_loader_data_raw_w[ROWS];
  logic signed [   ACT_W-1:0] act_loader_data_w[ROWS];
  logic                       act_loader_valid_w;

  logic                       weight_loader_en_w;
  logic        [  ADDR_W-1:0] weight_loader_addr_w;
  logic        [WEIGHT_W-1:0] weight_loader_data_raw_w[COLS];
  logic signed [WEIGHT_W-1:0] weight_loader_data_w[COLS];
  logic                       weight_loader_valid_w;

  logic                       acc_loader_en_w;
  logic        [  ADDR_W-1:0] acc_loader_addr_w;
  logic        [   ACC_W-1:0] acc_loader_data_raw_w[COLS];
  logic signed [   ACC_W-1:0] acc_loader_data_w[COLS];
  logic                       acc_loader_valid_w;

  logic signed [   ACT_W-1:0] act_w[ROWS];
  logic signed [WEIGHT_W-1:0] weight_w[COLS];
  logic                       act_valid_w[ROWS];
  logic                       weight_valid_w;
  logic                       array_acc_valid_w[COLS];
  logic signed [   ACC_W-1:0] array_acc_w[COLS];

  logic                       accum_valid_w;
  logic                       accum_first_w;
  logic                       accum_lane_valid_w[COLS];
  logic signed [   ACC_W-1:0] accum_old_data_w[COLS];
  logic signed [   ACC_W-1:0] accum_partial_data_w[COLS];
  logic                       accum_result_valid_w;
  logic signed [   ACC_W-1:0] accum_result_data_w[COLS];

  logic                       storer_valid_w;
  logic        [  ADDR_W-1:0] storer_addr_w;
  logic signed [   ACC_W-1:0] storer_data_w[COLS];

  genvar lane;
  generate
    for (lane = 0; lane < ROWS; lane++) begin : g_cast_act_loader
      assign act_loader_data_w[lane] = $signed(act_loader_data_raw_w[lane]);
    end

    for (lane = 0; lane < COLS; lane++) begin : g_cast_weight_loader
      assign weight_loader_data_w[lane] = $signed(weight_loader_data_raw_w[lane]);
    end

    for (lane = 0; lane < COLS; lane++) begin : g_cast_acc_loader
      assign acc_loader_data_w[lane] = $signed(acc_loader_data_raw_w[lane]);
    end
  endgenerate

  bram_loader #(
      .ROWS        (ROWS),
      .DATA_W      (ACT_W),
      .BRAM_W      (ROWS * ACT_W),
      .ADDR_W      (ADDR_W),
      .READ_LATENCY(1)
  ) u_act_loader (
      .aclk_i     (aclk_i),
      .aresetn_i  (aresetn_i),
      .en_i       (act_loader_en_w),
      .addr_i     (act_loader_addr_w),
      .bram_en_o  (act_bram_en_o),
      .bram_addr_o(act_bram_addr_o),
      .bram_data_i(act_bram_data_i),
      .data_o     (act_loader_data_raw_w),
      .valid_o    (act_loader_valid_w)
  );

  bram_loader #(
      .ROWS        (COLS),
      .DATA_W      (WEIGHT_W),
      .BRAM_W      (COLS * WEIGHT_W),
      .ADDR_W      (ADDR_W),
      .READ_LATENCY(1)
  ) u_weight_loader (
      .aclk_i     (aclk_i),
      .aresetn_i  (aresetn_i),
      .en_i       (weight_loader_en_w),
      .addr_i     (weight_loader_addr_w),
      .bram_en_o  (weight_bram_en_o),
      .bram_addr_o(weight_bram_addr_o),
      .bram_data_i(weight_bram_data_i),
      .data_o     (weight_loader_data_raw_w),
      .valid_o    (weight_loader_valid_w)
  );

  bram_loader #(
      .ROWS        (COLS),
      .DATA_W      (ACC_W),
      .BRAM_W      (COLS * ACC_W),
      .ADDR_W      (ADDR_W),
      .READ_LATENCY(1)
  ) u_acc_loader (
      .aclk_i     (aclk_i),
      .aresetn_i  (aresetn_i),
      .en_i       (acc_loader_en_w),
      .addr_i     (acc_loader_addr_w),
      .bram_en_o  (acc_rd_bram_en_o),
      .bram_addr_o(acc_rd_bram_addr_o),
      .bram_data_i(acc_rd_bram_data_i),
      .data_o     (acc_loader_data_raw_w),
      .valid_o    (acc_loader_valid_w)
  );

  systolic_array_fsm_ws #(
      .ROWS    (ROWS),
      .COLS    (COLS),
      .ACT_W   (ACT_W),
      .WEIGHT_W(WEIGHT_W),
      .ACC_W   (ACC_W),
      .ADDR_W  (ADDR_W)
  ) u_fsm (
      .aclk_i                (aclk_i),
      .aresetn_i             (aresetn_i),
      .start_i               (start_i),
      .m_size_i              (m_size_i),
      .n_size_i              (n_size_i),
      .k_size_i              (k_size_i),
      .act_base_addr_i       (act_base_addr_i),
      .weight_base_addr_i    (weight_base_addr_i),
      .acc_base_addr_i       (acc_base_addr_i),
      .act_loader_en_o       (act_loader_en_w),
      .act_loader_addr_o     (act_loader_addr_w),
      .act_loader_data_i     (act_loader_data_w),
      .act_loader_valid_i    (act_loader_valid_w),
      .weight_loader_en_o    (weight_loader_en_w),
      .weight_loader_addr_o  (weight_loader_addr_w),
      .weight_loader_data_i  (weight_loader_data_w),
      .weight_loader_valid_i (weight_loader_valid_w),
      .act_o                 (act_w),
      .weight_o              (weight_w),
      .act_valid_o           (act_valid_w),
      .weight_valid_o        (weight_valid_w),
      .acc_valid_i           (array_acc_valid_w),
      .acc_i                 (array_acc_w),
      .acc_loader_en_o       (acc_loader_en_w),
      .acc_loader_addr_o     (acc_loader_addr_w),
      .acc_loader_data_i     (acc_loader_data_w),
      .acc_loader_valid_i    (acc_loader_valid_w),
      .accum_valid_o         (accum_valid_w),
      .accum_first_o         (accum_first_w),
      .accum_lane_valid_o    (accum_lane_valid_w),
      .accum_old_data_o      (accum_old_data_w),
      .accum_partial_data_o  (accum_partial_data_w),
      .accum_valid_i         (accum_result_valid_w),
      .accum_data_i          (accum_result_data_w),
      .storer_valid_o        (storer_valid_w),
      .storer_addr_o         (storer_addr_w),
      .storer_data_o         (storer_data_w),
      .done_o                (done_o)
  );

  systolic_array_ws #(
      .ROWS    (ROWS),
      .COLS    (COLS),
      .ACT_W   (ACT_W),
      .WEIGHT_W(WEIGHT_W),
      .ACC_W   (ACC_W)
  ) u_array (
      .aclk_i        (aclk_i),
      .aresetn_i     (aresetn_i),
      .weight_valid_i(weight_valid_w),
      .act_valid_i   (act_valid_w),
      .act_i         (act_w),
      .weight_i      (weight_w),
      .acc_valid_o   (array_acc_valid_w),
      .acc_o         (array_acc_w)
  );

  accumulator #(
      .LANES (COLS),
      .DATA_W(ACC_W)
  ) u_accumulator (
      .valid_i       (accum_valid_w),
      .first_i       (accum_first_w),
      .lane_valid_i  (accum_lane_valid_w),
      .old_data_i    (accum_old_data_w),
      .partial_data_i(accum_partial_data_w),
      .valid_o       (accum_result_valid_w),
      .acc_data_o    (accum_result_data_w)
  );

  bram_storer #(
      .LANES (COLS),
      .DATA_W(ACC_W),
      .BRAM_W(COLS * ACC_W),
      .ADDR_W(ADDR_W)
  ) u_acc_storer (
      .aclk_i     (aclk_i),
      .aresetn_i  (aresetn_i),
      .valid_i    (storer_valid_w),
      .addr_i     (storer_addr_w),
      .data_i     (storer_data_w),
      .bram_en_o  (acc_wr_bram_en_o),
      .bram_we_o  (acc_wr_bram_we_o),
      .bram_addr_o(acc_wr_bram_addr_o),
      .bram_data_o(acc_wr_bram_data_o)
  );

endmodule

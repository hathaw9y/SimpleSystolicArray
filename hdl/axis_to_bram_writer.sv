module axis_to_bram_writer #(
    parameter int DATA_W = 32,
    parameter int ADDR_W = 10,
    parameter int LEN_W  = 16
) (
    input logic aclk_i,
    input logic aresetn_i,

    input  logic              start_i,
    input  logic [ADDR_W-1:0] base_addr_i,
    input  logic [ LEN_W-1:0] length_i,
    output logic              busy_o,
    output logic              done_o,
    output logic              error_o,

    input  logic [DATA_W-1:0] s_axis_tdata_i,
    input  logic              s_axis_tvalid_i,
    output logic              s_axis_tready_o,
    input  logic              s_axis_tlast_i,

    output logic              bram_en_o,
    output logic              bram_we_o,
    output logic [ADDR_W-1:0] bram_addr_o,
    output logic [DATA_W-1:0] bram_data_o
);

  logic              busy_r;
  logic [ADDR_W-1:0] addr_r;
  logic [ LEN_W-1:0] beat_cnt_r;
  logic [ LEN_W-1:0] length_r;
  logic              error_r;

  logic              axis_fire_w;
  logic              last_beat_w;
  logic              tlast_error_w;

  assign busy_o = busy_r;
  assign error_o = error_r;
  assign s_axis_tready_o = busy_r;

  assign axis_fire_w = s_axis_tvalid_i && s_axis_tready_o;
  assign last_beat_w = (beat_cnt_r == (length_r - LEN_W'(1)));
  assign tlast_error_w   = axis_fire_w &&
                           ((last_beat_w && !s_axis_tlast_i) ||
                            (!last_beat_w && s_axis_tlast_i));

  assign bram_en_o = axis_fire_w;
  assign bram_we_o = axis_fire_w;
  assign bram_addr_o = addr_r;
  assign bram_data_o = s_axis_tdata_i;

  always_ff @(posedge aclk_i or negedge aresetn_i) begin
    if (!aresetn_i) begin
      busy_r     <= 1'b0;
      addr_r     <= '0;
      beat_cnt_r <= '0;
      length_r   <= '0;
      done_o     <= 1'b0;
      error_r    <= 1'b0;
    end else begin
      done_o <= 1'b0;

      if (start_i && !busy_r) begin
        addr_r     <= base_addr_i;
        beat_cnt_r <= '0;
        length_r   <= length_i;
        error_r    <= 1'b0;

        if (length_i == '0) begin
          busy_r <= 1'b0;
          done_o <= 1'b1;
        end else begin
          busy_r <= 1'b1;
        end
      end else if (axis_fire_w) begin
        if (tlast_error_w) begin
          error_r <= 1'b1;
        end

        if (last_beat_w || s_axis_tlast_i) begin
          busy_r <= 1'b0;
          done_o <= 1'b1;
        end else begin
          addr_r     <= addr_r + ADDR_W'(1);
          beat_cnt_r <= beat_cnt_r + LEN_W'(1);
        end
      end
    end
  end

endmodule

module bram_to_axis_reader #(
    parameter int DATA_W = 32,
    parameter int ADDR_W = 9,
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

    output logic [DATA_W-1:0] m_axis_tdata_o,
    output logic              m_axis_tvalid_o,
    input  logic              m_axis_tready_i,
    output logic              m_axis_tlast_o,

    output logic              bram_en_o,
    output logic [ADDR_W-1:0] bram_addr_o,
    input  logic [DATA_W-1:0] bram_data_i
);

  logic              busy_r;
  logic [ADDR_W-1:0] addr_r;
  logic [ LEN_W-1:0] issued_cnt_r;
  logic [ LEN_W-1:0] length_r;
  logic              pending_r;
  logic              pending_last_r;
  logic              valid_r;
  logic              last_r;
  logic [DATA_W-1:0] data_r;

  logic              issue_read_w;
  logic              axis_fire_w;

  assign busy_o = busy_r;
  assign error_o = 1'b0;

  assign m_axis_tdata_o = data_r;
  assign m_axis_tvalid_o = valid_r;
  assign m_axis_tlast_o = last_r;

  assign issue_read_w = busy_r && !pending_r && !valid_r && (issued_cnt_r < length_r);
  assign axis_fire_w = m_axis_tvalid_o && m_axis_tready_i;

  assign bram_en_o = issue_read_w;
  assign bram_addr_o = addr_r;

  always_ff @(posedge aclk_i or negedge aresetn_i) begin
    if (!aresetn_i) begin
      busy_r         <= 1'b0;
      addr_r         <= '0;
      issued_cnt_r   <= '0;
      length_r       <= '0;
      pending_r      <= 1'b0;
      pending_last_r <= 1'b0;
      valid_r        <= 1'b0;
      last_r         <= 1'b0;
      data_r         <= '0;
      done_o         <= 1'b0;
    end else begin
      done_o <= 1'b0;

      if (start_i && !busy_r) begin
        addr_r         <= base_addr_i;
        issued_cnt_r   <= '0;
        length_r       <= length_i;
        pending_r      <= 1'b0;
        pending_last_r <= 1'b0;
        valid_r        <= 1'b0;
        last_r         <= 1'b0;

        if (length_i == '0) begin
          busy_r <= 1'b0;
          done_o <= 1'b1;
        end else begin
          busy_r <= 1'b1;
        end
      end else begin
        if (axis_fire_w) begin
          valid_r <= 1'b0;

          if (last_r) begin
            busy_r <= 1'b0;
            done_o <= 1'b1;
          end
        end

        if (pending_r) begin
          pending_r <= 1'b0;
          valid_r   <= 1'b1;
          data_r    <= bram_data_i;
          last_r    <= pending_last_r;
        end

        if (issue_read_w) begin
          pending_r      <= 1'b1;
          pending_last_r <= (issued_cnt_r == (length_r - LEN_W'(1)));
          issued_cnt_r   <= issued_cnt_r + LEN_W'(1);
          addr_r         <= addr_r + ADDR_W'(1);
        end
      end
    end
  end

endmodule

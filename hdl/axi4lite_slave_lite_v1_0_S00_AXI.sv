`timescale 1 ns / 1 ps

module axi4lite_slave_lite_v1_0_S00_AXI #(
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 4
) (
    output logic [C_S_AXI_DATA_WIDTH-1:0] m_size_o,
    output logic [C_S_AXI_DATA_WIDTH-1:0] n_size_o,
    output logic [C_S_AXI_DATA_WIDTH-1:0] k_size_o,
    output logic                          start_o,
    input  logic                          done_i,
    input  logic                          busy_i,

    input  logic                                      S_AXI_ACLK,
    input  logic                                      S_AXI_ARESETN,
    input  logic [    C_S_AXI_ADDR_WIDTH-1:0]         S_AXI_AWADDR,
    input  logic [                         2:0]       S_AXI_AWPROT,
    input  logic                                      S_AXI_AWVALID,
    output logic                                      S_AXI_AWREADY,
    input  logic [    C_S_AXI_DATA_WIDTH-1:0]         S_AXI_WDATA,
    input  logic [(C_S_AXI_DATA_WIDTH/8)-1:0]         S_AXI_WSTRB,
    input  logic                                      S_AXI_WVALID,
    output logic                                      S_AXI_WREADY,
    output logic [                         1:0]       S_AXI_BRESP,
    output logic                                      S_AXI_BVALID,
    input  logic                                      S_AXI_BREADY,
    input  logic [    C_S_AXI_ADDR_WIDTH-1:0]         S_AXI_ARADDR,
    input  logic [                         2:0]       S_AXI_ARPROT,
    input  logic                                      S_AXI_ARVALID,
    output logic                                      S_AXI_ARREADY,
    output logic [    C_S_AXI_DATA_WIDTH-1:0]         S_AXI_RDATA,
    output logic [                         1:0]       S_AXI_RRESP,
    output logic                                      S_AXI_RVALID,
    input  logic                                      S_AXI_RREADY
);

  localparam int ADDR_LSB = (C_S_AXI_DATA_WIDTH / 32) + 1;
  localparam int REG_SEL_W = C_S_AXI_ADDR_WIDTH - ADDR_LSB;

  localparam logic [1:0] AXI_RESP_OKAY = 2'b00;

  logic [C_S_AXI_ADDR_WIDTH-1:0] awaddr_r;
  logic                         awaddr_valid_r;
  logic [C_S_AXI_DATA_WIDTH-1:0] wdata_r;
  logic [(C_S_AXI_DATA_WIDTH/8)-1:0] wstrb_r;
  logic                         wdata_valid_r;
  logic [C_S_AXI_DATA_WIDTH-1:0] rdata_r;

  logic [C_S_AXI_DATA_WIDTH-1:0] m_size_r;
  logic [C_S_AXI_DATA_WIDTH-1:0] n_size_r;
  logic [C_S_AXI_DATA_WIDTH-1:0] k_size_r;
  logic                         done_r;

  logic                         write_fire_w;
  logic [REG_SEL_W-1:0]         write_sel_w;
  logic [REG_SEL_W-1:0]         read_sel_w;
  logic [C_S_AXI_DATA_WIDTH-1:0] ctrl_status_w;

  assign m_size_o = m_size_r;
  assign n_size_o = n_size_r;
  assign k_size_o = k_size_r;

  assign S_AXI_BRESP = AXI_RESP_OKAY;
  assign S_AXI_RRESP = AXI_RESP_OKAY;
  assign S_AXI_RDATA = rdata_r;

  assign S_AXI_AWREADY = !awaddr_valid_r && !S_AXI_BVALID;
  assign S_AXI_WREADY  = !wdata_valid_r && !S_AXI_BVALID;
  assign S_AXI_ARREADY = !S_AXI_RVALID;

  assign write_fire_w = awaddr_valid_r && wdata_valid_r && !S_AXI_BVALID;
  assign write_sel_w = awaddr_r[C_S_AXI_ADDR_WIDTH-1:ADDR_LSB];
  assign read_sel_w = S_AXI_ARADDR[C_S_AXI_ADDR_WIDTH-1:ADDR_LSB];

  assign ctrl_status_w = {
    {(C_S_AXI_DATA_WIDTH - 2) {1'b0}},
    busy_i,
    done_r
  };

  function automatic logic [C_S_AXI_DATA_WIDTH-1:0] apply_wstrb(
      input logic [C_S_AXI_DATA_WIDTH-1:0] old_value,
      input logic [C_S_AXI_DATA_WIDTH-1:0] new_value,
      input logic [(C_S_AXI_DATA_WIDTH/8)-1:0] strobe
  );
    logic [C_S_AXI_DATA_WIDTH-1:0] value;
    begin
      value = old_value;
      for (int byte_idx = 0; byte_idx < (C_S_AXI_DATA_WIDTH / 8); byte_idx++) begin
        if (strobe[byte_idx]) begin
          value[byte_idx*8+:8] = new_value[byte_idx*8+:8];
        end
      end
      apply_wstrb = value;
    end
  endfunction

  function automatic logic [C_S_AXI_DATA_WIDTH-1:0] read_reg(
      input logic [REG_SEL_W-1:0] reg_sel
  );
    begin
      case (reg_sel)
        REG_SEL_W'(0): read_reg = ctrl_status_w;
        REG_SEL_W'(1): read_reg = m_size_r;
        REG_SEL_W'(2): read_reg = n_size_r;
        REG_SEL_W'(3): read_reg = k_size_r;
        default:       read_reg = '0;
      endcase
    end
  endfunction

  always_ff @(posedge S_AXI_ACLK) begin
    if (!S_AXI_ARESETN) begin
      awaddr_r       <= '0;
      awaddr_valid_r <= 1'b0;
      wdata_r        <= '0;
      wstrb_r        <= '0;
      wdata_valid_r  <= 1'b0;
      S_AXI_BVALID   <= 1'b0;
      S_AXI_RVALID   <= 1'b0;
      rdata_r        <= '0;
      m_size_r       <= '0;
      n_size_r       <= '0;
      k_size_r       <= '0;
      start_o        <= 1'b0;
      done_r         <= 1'b0;
    end else begin
      start_o <= 1'b0;

      if (done_i) begin
        done_r <= 1'b1;
      end

      if (S_AXI_AWVALID && S_AXI_AWREADY) begin
        awaddr_r       <= S_AXI_AWADDR;
        awaddr_valid_r <= 1'b1;
      end

      if (S_AXI_WVALID && S_AXI_WREADY) begin
        wdata_r       <= S_AXI_WDATA;
        wstrb_r       <= S_AXI_WSTRB;
        wdata_valid_r <= 1'b1;
      end

      if (write_fire_w) begin
        case (write_sel_w)
          REG_SEL_W'(0): begin
            if (wstrb_r[0]) begin
              if (wdata_r[0]) begin
                start_o <= 1'b1;
                done_r  <= 1'b0;
              end

              if (wdata_r[1]) begin
                done_r <= 1'b0;
              end
            end
          end

          REG_SEL_W'(1): begin
            m_size_r <= apply_wstrb(m_size_r, wdata_r, wstrb_r);
          end

          REG_SEL_W'(2): begin
            n_size_r <= apply_wstrb(n_size_r, wdata_r, wstrb_r);
          end

          REG_SEL_W'(3): begin
            k_size_r <= apply_wstrb(k_size_r, wdata_r, wstrb_r);
          end

          default: begin
          end
        endcase

        awaddr_valid_r <= 1'b0;
        wdata_valid_r  <= 1'b0;
        S_AXI_BVALID   <= 1'b1;
      end else if (S_AXI_BVALID && S_AXI_BREADY) begin
        S_AXI_BVALID <= 1'b0;
      end

      if (S_AXI_ARVALID && S_AXI_ARREADY) begin
        rdata_r      <= read_reg(read_sel_w);
        S_AXI_RVALID <= 1'b1;
      end else if (S_AXI_RVALID && S_AXI_RREADY) begin
        S_AXI_RVALID <= 1'b0;
      end
    end
  end

endmodule

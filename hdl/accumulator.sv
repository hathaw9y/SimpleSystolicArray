module accumulator #(
    parameter int LANES  = 16,
    parameter int DATA_W = 32
) (
    input  logic                         valid_i,
    input  logic                         first_i,
    input  logic                         lane_valid_i  [LANES],
    input  logic signed [DATA_W-1:0]     old_data_i    [LANES],
    input  logic signed [DATA_W-1:0]     partial_data_i[LANES],
    output logic                         valid_o,
    output logic signed [DATA_W-1:0]     acc_data_o    [LANES]
);

  assign valid_o = valid_i;

  always_comb begin
    acc_data_o = '{default: '0};

    for (int i = 0; i < LANES; i++) begin
      if (lane_valid_i[i]) begin
        if (first_i) begin
          acc_data_o[i] = partial_data_i[i];
        end else begin
          acc_data_o[i] = $signed(old_data_i[i]) + $signed(partial_data_i[i]);
        end
      end
    end
  end

endmodule

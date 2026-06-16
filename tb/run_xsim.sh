#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

vivado_lib="${VIVADO_LIB:-/tools/Xilinx/Vivado/2024.1/lib/lnx64.o}"
export LD_LIBRARY_PATH="${vivado_lib}${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"

run_sim() {
  local top="$1"
  shift

  local snapshot="${top}_standalone"

  xvlog -sv "$@"
  xelab "$top" -s "$snapshot" -a
  "xsim.dir/${snapshot}/axsim"
}

run_sim tb_pe_os hdl/pe_os.sv tb/tb_pe_os.sv
run_sim tb_systolic_array_os_non_skew hdl/pe_os.sv hdl/systolic_array_os_non_skew.sv tb/tb_systolic_array_os_non_skew.sv
run_sim tb_systolic_array_os hdl/pipeline_reg.sv hdl/pe_os.sv hdl/systolic_array_os.sv tb/tb_systolic_array_os.sv
run_sim tb_gemm_fsm_os hdl/systolic_array_fsm_os.sv tb/tb_gemm_fsm_os.sv
run_sim tb_gemm_fsm_ws hdl/accumulator.sv hdl/systolic_array_fsm_ws.sv tb/tb_gemm_fsm_ws.sv
run_sim tb_axis_to_bram_writer hdl/axis_to_bram_writer.sv tb/tb_axis_to_bram_writer.sv
run_sim tb_bram_to_axis_reader hdl/bram_to_axis_reader.sv tb/tb_bram_to_axis_reader.sv
run_sim tb_axi4lite_slave_lite hdl/axi4lite_slave_lite_v1_0_S00_AXI.sv tb/tb_axi4lite_slave_lite.sv
run_sim tb_systolic_array_engine_os hdl/bram_loader.sv hdl/bram_storer.sv hdl/pipeline_reg.sv hdl/pe_os.sv hdl/systolic_array_os.sv hdl/systolic_array_fsm_os.sv hdl/systolic_array_engine_os.sv tb/tb_systolic_array_engine_os.sv
run_sim tb_systolic_array_engine_ws hdl/bram_loader.sv hdl/bram_storer.sv hdl/pipeline_reg.sv hdl/pe_ws.sv hdl/systolic_array_ws.sv hdl/systolic_array_fsm_ws.sv hdl/accumulator.sv hdl/systolic_array_engine_ws.sv tb/tb_systolic_array_engine_ws.sv
run_sim tb_pe_ws_weight_valid hdl/pe_ws.sv tb/tb_pe_ws_weight_valid.sv
run_sim tb_systolic_array_ws_weight_valid hdl/pipeline_reg.sv hdl/pe_ws.sv hdl/systolic_array_ws.sv tb/tb_systolic_array_ws_weight_valid.sv
run_sim tb_systolic_array_ws_non_skew_weight_valid hdl/pe_ws.sv hdl/systolic_array_ws_non_skew.sv tb/tb_systolic_array_ws_non_skew_weight_valid.sv

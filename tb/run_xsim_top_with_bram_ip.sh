#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

vivado_lib="${VIVADO_LIB:-/tools/Xilinx/Vivado/2024.1/lib/lnx64.o}"
export LD_LIBRARY_PATH="${vivado_lib}${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"

: "${BMG_COMMON:?Set BMG_COMMON to blk_mem_gen_v8_4.v}"
: "${BMG_W128:?Set BMG_W128 to w128_d512_blk_mem.v}"
: "${BMG_W512:?Set BMG_W512 to w512_d512_blk_mem.v}"

for src in "$BMG_COMMON" "$BMG_W128" "$BMG_W512"; do
  if [[ ! -f "$src" ]]; then
    echo "Missing file: $src" >&2
    exit 1
  fi
done

BMG_IP_SOURCES=("$BMG_COMMON" "$BMG_W128" "$BMG_W512")

run_sim() {
  local top="$1"
  shift

  local snapshot="${top}_standalone"
  local status=0
  local sim_log

  sim_log="$(mktemp)"

  xvlog -sv "$@"
  xelab "$top" -s "$snapshot" -a
  "xsim.dir/${snapshot}/axsim" 2>&1 | tee "$sim_log" || status=$?
  if grep -q "^Error:" "$sim_log"; then
    status=1
  fi
  rm -f "$sim_log"

  rm -f xvlog.log xvlog.pb xelab.log xelab.pb xsim.log xsim.jou
  find xsim.dir -name "*.log" -delete 2>/dev/null || true

  return "$status"
}

run_sim tb_systolic_array_top_os \
  hdl/axi4lite_slave_lite_v1_0_S00_AXI.sv \
  hdl/systolic_array_controller_os.sv \
  hdl/axis_to_bram_writer.sv \
  hdl/bram_to_axis_reader.sv \
  hdl/bram_loader.sv \
  hdl/bram_storer.sv \
  hdl/pipeline_reg.sv \
  hdl/pe_os.sv \
  hdl/systolic_array_os.sv \
  hdl/systolic_array_fsm_os.sv \
  hdl/systolic_array_engine_os.sv \
  hdl/systolic_array_top_os.sv \
  "${BMG_IP_SOURCES[@]}" \
  tb/tb_systolic_array_top_os.sv

run_sim tb_systolic_array_top_os_identity \
  hdl/axi4lite_slave_lite_v1_0_S00_AXI.sv \
  hdl/systolic_array_controller_os.sv \
  hdl/axis_to_bram_writer.sv \
  hdl/bram_to_axis_reader.sv \
  hdl/bram_loader.sv \
  hdl/bram_storer.sv \
  hdl/pipeline_reg.sv \
  hdl/pe_os.sv \
  hdl/systolic_array_os.sv \
  hdl/systolic_array_fsm_os.sv \
  hdl/systolic_array_engine_os.sv \
  hdl/systolic_array_top_os.sv \
  "${BMG_IP_SOURCES[@]}" \
  tb/tb_systolic_array_top_os_identity.sv

run_sim tb_systolic_array_top_ws \
  hdl/axi4lite_slave_lite_v1_0_S00_AXI.sv \
  hdl/systolic_array_controller_ws.sv \
  hdl/axis_to_bram_writer.sv \
  hdl/bram_to_axis_reader.sv \
  hdl/bram_loader.sv \
  hdl/bram_storer.sv \
  hdl/pipeline_reg.sv \
  hdl/pe_ws.sv \
  hdl/systolic_array_ws.sv \
  hdl/systolic_array_fsm_ws.sv \
  hdl/accumulator.sv \
  hdl/systolic_array_engine_ws.sv \
  hdl/systolic_array_top_ws.sv \
  "${BMG_IP_SOURCES[@]}" \
  tb/tb_systolic_array_top_ws.sv

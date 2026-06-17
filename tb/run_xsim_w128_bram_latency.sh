#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

vivado_lib="${VIVADO_LIB:-/tools/Xilinx/Vivado/2024.1/lib/lnx64.o}"
export LD_LIBRARY_PATH="${vivado_lib}${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"

: "${BMG_COMMON:?Set BMG_COMMON to blk_mem_gen_v8_4.v}"
: "${BMG_W128:?Set BMG_W128 to w128_d512_blk_mem.v}"

for src in "$BMG_COMMON" "$BMG_W128"; do
  if [[ ! -f "$src" ]]; then
    echo "Missing file: $src" >&2
    exit 1
  fi
done

top="tb_w128_d512_blk_mem_latency"
snapshot="${top}_standalone"
sim_log="$(mktemp)"
status=0

xvlog -sv "$BMG_COMMON" "$BMG_W128" "tb/${top}.sv"
xelab "$top" -s "$snapshot" -a
"xsim.dir/${snapshot}/axsim" 2>&1 | tee "$sim_log" || status=$?

if grep -q "^Error:" "$sim_log"; then
  status=1
fi

rm -f "$sim_log"
rm -f xvlog.log xvlog.pb xelab.log xelab.pb xsim.log xsim.jou
find xsim.dir -name "*.log" -delete 2>/dev/null || true

exit "$status"

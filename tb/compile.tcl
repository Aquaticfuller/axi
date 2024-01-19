# This script was generated automatically by bender.
set ROOT "/home/zexifu/c910_pulp/axi"

if {[catch {vlog -incr -sv \
    -suppress 2583 -suppress 13314 +define+SPIKE_TANDEM \
    +define+TARGET_C910 \
    +define+TARGET_COSIM \
    +define+TARGET_CV64A6_IMAFDCSCLIC_SV39 \
    +define+TARGET_CVA6 \
    +define+TARGET_RTL \
    +define+TARGET_SIM \
    +define+TARGET_SIMULATION \
    +define+TARGET_TEST \
    +define+TARGET_VSIM \
    "+incdir+$ROOT/include" \
    "$ROOT/src/axi_pkg.sv" \
    "$ROOT/.bender/git/checkouts/common_verification-5b9bacfe2f79eb87/src/clk_rst_gen.sv" \
    "$ROOT/src/axi_burst_undec.sv" \
    "$ROOT/tb/tb_axi_burst_undec.sv"
}]} {return 1}
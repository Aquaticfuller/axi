onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb_axi_burst_undec/i_dut/clk_i
add wave -noupdate /tb_axi_burst_undec/i_dut/rst_ni
add wave -noupdate -expand -subitemconfig {/tb_axi_burst_undec/i_dut/slv_req_i.w -expand} /tb_axi_burst_undec/i_dut/slv_req_i
add wave -noupdate /tb_axi_burst_undec/i_dut/slv_resp_o
add wave -noupdate -expand -subitemconfig {/tb_axi_burst_undec/i_dut/mst_req_o.w -expand} /tb_axi_burst_undec/i_dut/mst_req_o
add wave -noupdate /tb_axi_burst_undec/i_dut/mst_resp_i
add wave -noupdate /tb_axi_burst_undec/i_dut/state_q
add wave -noupdate /tb_axi_burst_undec/i_dut/w_burst_rec_cnt_q
add wave -noupdate /tb_axi_burst_undec/i_dut/w_burst_snd_cnt_q
add wave -noupdate -expand -subitemconfig {{/tb_axi_burst_undec/i_dut/w_q[1]} -expand} /tb_axi_burst_undec/i_dut/w_q
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {185395 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 150
configure wave -valuecolwidth 360
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ps
update
WaveRestoreZoom {51139 ps} {316323 ps}

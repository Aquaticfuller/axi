set TESTBENCH tb_axi_burst_undec

if {![info exists VOPTARGS]} {
    set VOPTARGS "+acc"
}


set flags "-permissive -suppress 3009 -suppress 8386 -error 7 "
if {[info exists SELCFG]} { append flags "-GSelectedCfg=${SELCFG} " }

set pargs ""
if {[info exists BOOTMODE]} { append pargs "+BOOTMODE=${BOOTMODE} " }
if {[info exists PRELMODE]} { append pargs "+PRELMODE=${PRELMODE} " }
if {[info exists BINARY]}   { append pargs "+BINARY=${BINARY} " }
if {[info exists BINARY2]}   { append pargs "+BINARY2=${BINARY2} " }
if {[info exists BINARY3]}   { append pargs "+BINARY3=${BINARY3} " }
if {[info exists IMAGE]}    { append pargs "+IMAGE=${IMAGE} " }

set questa-define "+define+SPIKE_TANDEM"

eval "vsim -c ${TESTBENCH} -t 1ps -vopt -voptargs=\"${VOPTARGS}\"" ${pargs} ${flags} ${questa-define}

set StdArithNoWarnings 1
set NumericStdNoWarnings 1
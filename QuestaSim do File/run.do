vlib work
vlog ALSU_pckg.sv ALSU_tb.sv  ALSU.sv +cover -covercells 
vsim -voptargs=+acc work.ALSU_tb -cover
add wave *
run -all

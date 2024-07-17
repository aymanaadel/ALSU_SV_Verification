vlib work
vlog ALSU_pckg.sv ALSU_tb.sv  ALSU.sv +cover -covercells 
vsim -voptargs=+acc work.ALSU_tb -cover
add wave *
coverage save ALSU_tb.ucdb -onexit
run -all
quit -sim
vcover report ALSU_tb.ucdb -details -annotate -all -output total_coverage.txt
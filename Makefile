PROJECT = nanoV

ICEPACK = icepack
NEXTPNR = nextpnr-ice40 --randomize-seed --up5k --package sg48
YOSYS = yosys
BIN2UF2 = bin2uf2
DFU-UTIL = dfu-util -R -a 1
DFU-SUFFIX = dfu-suffix -v 1209 -p b1c0

PICO_ICE_SDK = ../../pico-ice-sdk/
PCF_FILE = pico_ice.pcf
RTL = top.v nanoV/core.v nanoV/alu.v nanoV/register.v nanoV/shift.v nanoV/multiply.v nanoV/cpu.v nanoV/uart/uart_tx.v nanoV/uart/uart_rx.v

all: $(PROJECT).uf2 $(PROJECT).dfu

clean:
	rm -f *.log *.json *.asc *.bit *.dfu *.uf2
	rm -rf verilator

flash: pico_ice_bitstream.dfu
	$(DFU-UTIL) -D $(PROJECT).dfu

pico_ice_bitstream.json: ${RTL}

.SUFFIXES: .sv .elf .vcd .json .asc .bit .dfu .uf2

$(PROJECT).json: $(RTL)
	${YOSYS} -p "read_verilog ${RTL}; synth_ice40 -top $(PROJECT)_top -json $@" -DICE40 >$*.yosys.log
	-grep -e Error -e Warn $*.yosys.log

.json.asc:
	${NEXTPNR} -q -l $*.nextpnr.log --pcf $(PCF_FILE) --top $(PROJECT)_top --json $< --asc $@

.asc.bit:
	${ICEPACK} $< $@

.bit.uf2:
	$(BIN2UF2) -o $@ 0x00000000 $<

.bit.dfu:
	cp $< $@
	$(DFU-SUFFIX) -a $@


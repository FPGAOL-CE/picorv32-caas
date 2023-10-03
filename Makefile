DB_DIR = /nextpnr-xilinx/xilinx/external/prjxray-db
CHIPDB = /chipdb

BUILDDIR := ${CURDIR}/build
TOP := basys3_dummy
#SOURCES :=  $(wildcard basys3-dummy.v)  $(wildcard picorv32/picosoc/picosoc.v)  $(wildcard picorv32/picorv32.v)  $(wildcard picorv32/picosoc/simpleuart.v)  $(wildcard picorv32/picosoc/spimemio.v) 
XDC := $(wildcard basys3-dummy.xdc)

CHIPFAM := artix7
PART := xc7a35tcpg236-1

LOGFILE := ${BUILDDIR}/top.log

all: ${BUILDDIR} ${BUILDDIR}/top.bit

${BUILDDIR}:
	mkdir -m 777 -p ${BUILDDIR} && chown -R nobody ${BUILDDIR} | true

# we run this in parent directory to seeminglessly import user source files
# otherwise have to parse user pattern and add ../
${BUILDDIR}/top.json:  $(wildcard basys3-dummy.v)  $(wildcard picorv32/picosoc/picosoc.v)  $(wildcard picorv32/picorv32.v)  $(wildcard picorv32/picosoc/simpleuart.v)  $(wildcard picorv32/picosoc/spimemio.v) 
	yosys -p "synth_xilinx -flatten -abc9 -arch xc7 -top ${TOP}; write_json ${BUILDDIR}/top.json" $^ >> ${LOGFILE} 2>&1

# The chip database only needs to be generated once
# that is why we don't clean it with make clean
${CHIPDB}/${PART}.bin:
	pypy3 /nextpnr-xilinx/xilinx/python/bbaexport.py --device ${PART} --bba ${PART}.bba
	bbasm -l ${PART}.bba ${CHIPDB}/${PART}.bin
	rm -f ${PART}.bba

${BUILDDIR}/top.fasm: ${BUILDDIR}/top.json ${CHIPDB}/${PART}.bin
	nextpnr-xilinx --chipdb ${CHIPDB}/${PART}.bin --xdc ${XDC} --json ${BUILDDIR}/top.json --fasm $@ --verbose --debug >> ${LOGFILE} 2>&1
	
${BUILDDIR}/top.frames: ${BUILDDIR}/top.fasm
	fasm2frames --part ${PART} --db-root ${DB_DIR}/${CHIPFAM} $< > $@ #FIXME: fasm2frames should be on PATH

${BUILDDIR}/top.bit: ${BUILDDIR}/top.frames
	xc7frames2bit --part_file ${DB_DIR}/${CHIPFAM}/${PART}/part.yaml --part_name ${PART} --frm_file $< --output_file $@ >> ${LOGFILE} 2>&1

.PHONY: clean
clean:
	@rm -f *.bit
	@rm -f *.frames
	@rm -f *.fasm
	@rm -f *.json

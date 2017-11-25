
COMMON = src/8088/defs.inc src/8088/include/data.asm src/8088/include/init.asm src/8088/include/int.asm src/8088/include/ipc.asm
DEBUG = src/8088/include/debug.asm

all: bin/pc_tsr.com bin/pc_high.com bin/pc_debug.com bin/ipc.prg rom/card.bin bin/reboot.com bin/cls.com

bin/pc_tsr.com: src/8088/pc_tsr.asm $(COMMON)
	nasm src/8088/pc_tsr.asm -o bin/pc_tsr.com

bin/pc_high.com: src/8088/pc_high.asm $(COMMON)
	nasm src/8088/pc_high.asm -o bin/pc_high.com

bin/pc_debug.com: src/8088/pc_high.asm $(COMMON) $(DEBUG)
	nasm src/8088/pc_high.asm -dDEBUG -o bin/pc_debug.com

bin/ipc.prg: src/6509/ipc.asm
	xa src/6509/ipc.asm -O PETSCII -o bin/ipc.prg

rom/card.bin: src/8088/rom.asm src/8088/include/rom.asm
	nasm src/8088/rom.asm -w-lock -o rom/card.bin

bin/reboot.com: src/misc/reboot.asm
	nasm src/misc/reboot.asm -o bin/reboot.com

bin/cls.com: src/misc/cls.asm
	nasm src/misc/cls.asm -o bin/cls.com

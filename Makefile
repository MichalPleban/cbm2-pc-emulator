
PRG = dist/prg/8088.prg dist/prg/6509.prg
COM = dist/com/pc_tsr.com dist/com/pc_high.com dist/com/pc_debug.com
ROM = dist/rom/card.bin 
MISC = dist/misc/reboot.com dist/misc/cls.com

COMMON = src/8088/include/data.asm src/8088/include/init.asm src/8088/include/int.asm src/8088/include/ipc.asm src/8088/include/version.asm
INSTALL = src/8088/include/install.asm
DEBUG = src/8088/include/debug.asm

all: $(PRG) $(COM) $(ROM) $(MISC)

dist/prg/8088.prg: src/8088/ipc.asm $(COMMON) $(INSTALL)
	nasm src/8088/ipc.asm -o dist/prg/8088.prg

dist/prg/6509.prg: src/6509/ipc.asm
	xa src/6509/ipc.asm -O PETSCII -o dist/prg/6509.prg

dist/com/pc_tsr.com: src/8088/pc_tsr.asm $(COMMON)
	nasm src/8088/pc_tsr.asm -o dist/com/pc_tsr.com

dist/com/pc_high.com: src/8088/pc_high.asm $(COMMON) $(INSTALL)
	nasm src/8088/pc_high.asm -o dist/com/pc_high.com

dist/com/pc_debug.com: src/8088/pc_high.asm $(COMMON) $(INSTALL) $(DEBUG)
	nasm src/8088/pc_high.asm -dDEBUG -o dist/com/pc_debug.com

dist/rom/card.bin: src/8088/rom.asm src/8088/include/rom.asm
	nasm src/8088/rom.asm -w-lock -o dist/rom/card.bin

dist/misc/reboot.com: src/misc/reboot.asm
	nasm src/misc/reboot.asm -o dist/misc/reboot.com

dist/misc/cls.com: src/misc/cls.asm
	nasm src/misc/cls.asm -o dist/misc/cls.com

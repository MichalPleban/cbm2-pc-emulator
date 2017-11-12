
nasm src/8088/pc_tsr.asm -o bin/pc_tsr.com
nasm src/8088/pc_high.asm -o bin/pc_high.com
nasm src/8088/pc_high.asm -dDEBUG -o bin/pc_debug.com
nasm src/8088/rom.asm -w-lock -o rom/card.bin

xa src/6509/ipc.asm -O PETSCII -o bin/ipc.prg

nasm src/misc/reboot.asm -o bin/reboot.com
nasm src/misc/cls.asm -o bin/cls.com

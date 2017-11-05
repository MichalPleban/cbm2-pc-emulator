
nasm src/pc_tsr.asm -o bin/pc_tsr.com
nasm src/pc_high.asm -o bin/pc_high.com
nasm src/pc_high.asm -dDEBUG -o bin/pc_debug.com

nasm src/rom.asm -w-lock -o rom/card.bin

nasm src/misc/reboot.asm -o bin/reboot.com
nasm src/misc/cls.asm -o bin/cls.com

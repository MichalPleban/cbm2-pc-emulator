
PRG = dist/prg/6509.prg dist/prg/screen_nochar.prg dist/prg/screen_char.prg dist/prg/vga.prg
ROM = dist/rom/payload.bin dist/rom/8088.bin dist/rom/8088_devel.bin
UPGRADE = dist/upgrade/upgrade.com

TRACK = util/360_d80.trk util/360_d82.trk util/720_d82.trk
ONDISK = dist/prg/boot.prg $(PRG)

PAYLOAD = src/8088/payload/data.asm src/8088/payload/init.asm src/8088/payload/int.asm src/8088/payload/ipc.asm src/8088/payload/sd.asm src/8088/payload/i2c.asm src/8088/payload/screen.asm src/8088/payload/config.asm src/8088/payload/hardware.asm src/8088/payload/virtual.asm
VIRTUAL = src/8088/virtual/speaker.asm src/8088/virtual/serial.asm src/8088/virtual/pic.asm src/8088/virtual/pit.asm src/8088/virtual/mda.asm src/8088/virtual/kbd.asm
START = src/8088/rom/ipc.asm src/8088/rom/bootstrap.asm
DEBUG = src/8088/include/debug.asm

all: $(PRG) $(ROM) $(TRACK) $(DISK) $(EMPTY) $(UPGRADE)

dist/prg/6509.prg: src/6509/ipc.asm src/6509/io.inc
	ca65 src/6509/ipc.asm
	ld65 src/6509/ipc.o -C src/6509/6509.cfg -o dist/prg/6509.prg
	rm src/6509/ipc.o

dist/prg/screen_nochar.prg: src/6509/screen.asm
	ca65 -D NOCHAR src/6509/screen.asm
	ld65 src/6509/screen.o -C src/6509/6509.cfg -o dist/prg/screen_nochar.prg
	rm src/6509/screen.o

dist/prg/screen_char.prg: src/6509/screen.asm
	ca65 -D CHAR src/6509/screen.asm
	ld65 src/6509/screen.o -C src/6509/6509.cfg -o dist/prg/screen_char.prg
	rm src/6509/screen.o

dist/prg/vga.prg: src/6509/vga.asm
	ca65 src/6509/vga.asm
	ld65 src/6509/vga.o -C src/6509/6509.cfg -o dist/prg/vga.prg
	rm src/6509/vga.o

dist/rom/payload.bin: src/8088/payload.asm $(PAYLOAD) $(VIRTUAL) $(PRG)
	util/incbuild.pl src/8088/build.inc
	nasm src/8088/payload.asm -w-lock -w-number-overflow -o dist/rom/payload.bin -l test.lst

dist/rom/8088.bin: src/8088/rom.asm dist/rom/payload.bin $(START)
	nasm src/8088/rom.asm -w-lock -w-number-overflow -o dist/rom/8088.bin

dist/rom/8088_devel.bin: src/8088/rom.asm dist/rom/payload.bin $(START)
	nasm src/8088/rom.asm -DDEVEL -w-lock -w-number-overflow -l test.lst -o dist/rom/8088_devel.bin

dist/upgrade/upgrade.com: src/8088/upgrade.asm dist/rom/payload.bin
	nasm src/8088/upgrade.asm -o dist/upgrade/upgrade.com

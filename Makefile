
PRG = dist/prg/6509.prg dist/prg/screen_nochar.prg dist/prg/screen_char.prg
ROM = dist/rom/payload.bin dist/rom/card.bin dist/rom/card_devel.bin
UPGRADE = dist/upgrade/upgrade.com

TRACK = util/360_d80.trk util/360_d82.trk util/720_d82.trk
ONDISK = dist/prg/boot.prg $(PRG)

PAYLOAD = src/8088/payload/data.asm src/8088/payload/init.asm src/8088/payload/int.asm src/8088/payload/ipc.asm src/8088/payload/sd.asm src/8088/payload/i2c.asm src/8088/payload/screen.asm src/8088/payload/config.asm src/8088/payload/hardware.asm src/8088/payload/virtual.asm
START = src/8088/rom/ipc.asm src/8088/rom/bootstrap.asm
DEBUG = src/8088/include/debug.asm

all: $(PRG) $(ROM) $(TRACK) $(DISK) $(EMPTY) $(UPGRADE)

dist/prg/6509.prg: src/6509/ipc.asm
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

dist/rom/payload.bin: src/8088/payload.asm $(PAYLOAD) $(PRG)
	util/incbuild.pl src/8088/build.inc
	nasm src/8088/payload.asm -w-lock -w-number-overflow -o dist/rom/payload.bin

dist/rom/card.bin: src/8088/rom.asm dist/rom/payload.bin $(START)
	nasm src/8088/rom.asm -w-lock -w-number-overflow -o dist/rom/card.bin

dist/rom/card_devel.bin: src/8088/rom.asm dist/rom/payload.bin $(START)
	nasm src/8088/rom.asm -DDEVEL -w-lock -w-number-overflow -o dist/rom/card_devel.bin

dist/upgrade/upgrade.com: src/8088/upgrade.asm dist/rom/payload.bin
	nasm src/8088/upgrade.asm -o dist/upgrade/upgrade.com

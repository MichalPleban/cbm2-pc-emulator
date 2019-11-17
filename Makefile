
PRG = dist/prg/6509.prg dist/prg/8088.prg dist/prg/screen_nochar.prg dist/prg/screen_char.prg
ROM = dist/rom/payload.bin dist/rom/card.bin dist/rom/card_devel.bin

TRACK = util/360_d80.trk util/360_d82.trk util/720_d82.trk
ONDISK = dist/prg/boot.prg $(PRG)
DISK = dist/disk/freedos.d82 dist/disk/pcdos33.d82 dist/disk/pcdos33a.d80 dist/disk/pcdos33b.d80 dist/disk/pcdos32.d82 dist/disk/pcdos32a.d80 dist/disk/pcdos32b.d80
EMPTY = dist/disk/empty/empty360.d80 dist/disk/empty/empty360.d82 dist/disk/empty/empty720.d82

PAYLOAD = src/8088/payload/data.asm src/8088/payload/init.asm src/8088/payload/int.asm src/8088/payload/ipc.asm src/8088/payload/sd.asm src/8088/payload/i2c.asm src/8088/payload/screen.asm
START = src/8088/rom/ipc.asm src/8088/rom/bootstrap.asm
DEBUG = src/8088/include/debug.asm

all: $(PRG) $(ROM) $(TRACK) $(DISK) $(EMPTY)

# Uncomment for interrupt debugging
#dist/prg/8088.prg: src/8088/ipc.asm $(COMMON) $(DEBUG)
#	nasm src/8088/ipc.asm -dDEBUG -o dist/prg/8088.prg

dist/prg/8088.prg: src/8088/ipc.asm $(COMMON)
	nasm src/8088/ipc.asm -o dist/prg/8088.prg

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

util/360_d80.trk: src/track/360_d80.trk $(ONDISK) dist/prg/bamfix/bamfix-360.prg
	util/insert.pl src/track/360_d80.trk util/360_d80.trk $(ONDISK) dist/prg/bamfix/bamfix-360.prg

util/360_d82.trk: src/track/360_d82.trk $(ONDISK) dist/prg/bamfix/bamfix-360.prg
	util/insert.pl src/track/360_d82.trk util/360_d82.trk $(ONDISK) dist/prg/bamfix/bamfix-360.prg

util/720_d82.trk: src/track/720_d82.trk $(ONDISK) dist/prg/bamfix/bamfix-720.prg
	util/insert.pl src/track/720_d82.trk util/720_d82.trk $(ONDISK) dist/prg/bamfix/bamfix-720.prg

dist/disk/pcdos33.d82 : util/720_d82.trk src/disk/pcdos33.img
	util/imager.pl -i src/disk/pcdos33.img -o dist/disk/pcdos33.d82 -b util

dist/disk/freedos.d82 : util/720_d82.trk src/disk/freedos.img
	util/imager.pl -i src/disk/freedos.img -o dist/disk/freedos.d82 -b util

dist/disk/pcdos33a.d80 : util/360_d80.trk src/disk/pcdos33a.img
	util/imager.pl -i src/disk/pcdos33a.img -o dist/disk/pcdos33a.d80 -b util

dist/disk/pcdos33b.d80 : util/360_d80.trk src/disk/pcdos33b.img
	util/imager.pl -i src/disk/pcdos33b.img -o dist/disk/pcdos33b.d80 -b util

dist/disk/pcdos32.d82 : util/720_d82.trk src/disk/pcdos32.img
	util/imager.pl -i src/disk/pcdos32.img -o dist/disk/pcdos32.d82 -b util

dist/disk/pcdos32a.d80 : util/360_d80.trk src/disk/pcdos32a.img
	util/imager.pl -i src/disk/pcdos32a.img -o dist/disk/pcdos32a.d80 -b util

dist/disk/pcdos32b.d80 : util/360_d80.trk src/disk/pcdos32b.img
	util/imager.pl -i src/disk/pcdos32b.img -o dist/disk/pcdos32b.d80 -b util

dist/disk/empty/empty360.d80 : util/360_d80.trk src/disk/empty/empty360.img
	util/imager.pl -i src/disk/empty/empty360.img -o dist/disk/empty/empty360.d80 -b util

dist/disk/empty/empty360.d82 : util/360_d82.trk src/disk/empty/empty360.img
	util/imager.pl -i src/disk/empty/empty360.img -o dist/disk/empty/empty360.d82 -b util

dist/disk/empty/empty720.d82 : util/720_d82.trk src/disk/empty/empty720.img
	util/imager.pl -i src/disk/empty/empty720.img -o dist/disk/empty/empty720.d82 -b util

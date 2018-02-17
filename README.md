# PC emulation layer

This software allows you to run IBM PC software on a Commodore 710 equipped with the 8088 card. The card has a dedicated MS-DOS 1.25 port that runs on it, but there is very little software that could be used with that old version. The computer is also not PC-compatible, so even the few software titles that support MS-DOS 1.x don't work.

The aim of the project is to emulate as much of the PC architecture in software as possible, to allow booting PC versions of MS-DOS and running PC software. Currently, PC-DOS versions 2.00 and 3.30 have been successfully booted using the emulation layer.

A PC-compatible font is also supplied, allowing to display characters that are not present in the PETSCII character set (such as \ | {} or CP437 graphics characters).

## Quick start guide

Use `cbmlink` (or other tool) to create a Commodore 8250 disk from the image `dist/disk/pcdos33.d82` (if you do not have the 8250 drive, you can use `pcdos33a.d80` instead).

Optionally, burn a 2764 EPROM with the contents of the `dist/rom/charset.bin` file and replace your computer's character ROM with it. It is not necessary, but doing so will enable the PC display font.

Insert the diskette in drive 0 and hit Shift+Run to start the system. If you burned the custom character ROM, you can press space while the sotware is booting, to enable the PC font. If the character ROM is installed successfullty, you should see the back arrow character in the startup message changing into the underscore character.

The boot file loads the emulation layer libraries and transfers control to the 8088 processor, which reads the boot sector from the diskette and executes it. Loading the PC-DOS 3.30 system takes about 2 minutes, due to slow speed of the IEEE drive. If you want to do something faster, you can use the image `dist/disk/pcdos11.d82` which contains PC-DOS 1.10 and boots under 20 seconds.

Loaded system runs inside the PC emulation layer. You can try different DOS commands - everything that is not tied directly to PC hardware (like GRAFTABL) should work.

## How does it work?

The emulation layer consists of two modules:

 * `6509.prg`, which contains the 6509 code implementing I/O functions. The 8088 processor has no access to the I/O, therefore it calls this module for every I/O operation.
 * `8088.prg`, which contains the 8088 code of the emulation layer.

The second file is roughly divided into the following parts:

 * High-level interrupt emulation routines, implementing part of the PC BIOS interrupts. This part is located in the `int.asm` file.
 * Low-level I/O routines, which interface to the 6509 processor and I/O services provided by it. This part is located in the `ipc.asm` file.

The high-level routines are fairly system-independent and could be adapted to another machine. The low-level routines are specific to the CBM-II.

### What is emulated?

The emulation layer presents itself as an IBM PC with a MDA graphics card, one serial and one parallel port. It provides the following services:

* INT 10 - functions 00, 02, 03, 06, 07, 09, 0A, 0E, 0F
* INT 11
* INT 12
* INT 13 - functions 00, 01, 02, 03, 04, 08, 15, 16
* INT 14 - functions 00, 01, 02, 03
* INT 16 - functions 00, 01, 02
* INT 17 - functions 00, 01, 02
* INT 18 and INT 19
* INT 1A - functions 00, 01

These services are sufficient to run MS-DOS and other software which does not rely on accessing PC hardware directly.

PC disk access is possible with the 8050 or 8250 drive; a script converting IMG files to D80 or D82 images is provided. These images need to be written to the Commodore diskette using software such as `cbmlink` - CBM drives cannot read PC disks directly due to different format (MFM vs GCR).

Additionally, the low-level routines emulate INT 08 and INT 1C using the 500 Hz timer of the CBM-II (this is important for software containing timing loops).

### What is not emulated?

PC hardware that doesn't exist in the CBM-II cannot be emulated. The most important part is video memory - if the software accesses video memory directly, it will not work (unfortunately, lots of software does that). Similarly, software that relies on keyboard interrupts, accesses I/O ports, and performs other hardware accesses will not work. 

Interrupt routines from IBM AT upwards are not emulated, except for a few functions of INT 13. This should not be needed, as the card has an 8088 processor so could not pass for an AT anyway.

BIOS data area at segment 0040h is not emulated - this area is used for IPC calls to the 6509 processor.

### How can it be used?

The easiest way to use the emulation layer is to take an IMG file of a PC diskette, and transform it into a D80 or D82 image using the `imager.pl` utility (described below).

The utility places all the required files on the Commodore disk, therefore booting the image is as simple as inserting the disk and pressing Shift+Run.

### What software does work?

Currently I am concentrating on booting PC version of MS-DOS and making it work. Once MS-DOS runs without problems, I plan to start testing various other software. Suggestions are welcome on what to try first.

## Compiling the software

The following tools are required to successfully build the system:

 * GNU make.
 * NASM (Netwide Assembler) - to compile the 8088 code. 
 * XA assembler - to compile the 6509 code.
 * Perl - to run disk imaging utilities.
 * c1541 (for example, from your VICE distribution) - to place compiled files in D80 and D82 images.

The compiled files are placed in the `dist` directory. The most important subdirectory there is the `disk` folder, where ready-to-run PC-DOS disk images are placed after successful compilation. You will need `cbmlink` or similar utility to transfer these images to your disk drive.

## Utilities

A few utilities are provided in the `utils` directory to assist in deoplying the emulation layer on the PC.

### Moving disks from the PC

In order to read a PC disk on the CBM-II, it must be written by a Commodore drive. The script `imager.pl` is provided to prepare disk images. Basic usage is:

```
imager.pl -i pc_disk.img -o cbm_disk.d80
```

You can put 160 kB, 180 kB and 360 kB images into a D80 or D82 disk; 720 kB images can be written only as D82. Larger images (1.2 or 1.44 MB) will not fit on a 8250 diskette. If the disk image has a correct BPB, the disk parameters (number of heads, sectors per track etc) will be read and interpreted correctly by the emulation layer upon first accessing sector 0,1.

The output image is created by writing the sector data sequentially onto the Commodore diskette, but omitting tracks 38 and 39. This way the Commodore diskette  still has its proper directory and BAM, and files can be stored in the remaining part of the disk. 

The `imager.pl` utility writes appropriate data on the tracks 38 and 39 of the Commodore disk - they are provided in the enclosed `*.trk` files. These data contain BAM with all the PC disk sectors allocated ad well as an empty CBM DOS directory.

PC diskettes have 512-byte sectors whereas Commodore drives use 256-byte sectors. Therefore, the emulation layer creates "virtual" 512-byte sectors from pairs of physical sectors.

The created D80 or D82 image must be written to the Commodore disk drive using your favorite tool (for example, `cbmlink`).

### Transferring files to the host OS

The native MS-DOS 1.25 host system contains a file `recv.exe` that can be used to transmit files from a PC to the host disk over a RS-232 connection. You can use this tool to transfer recompiled emulation layer files to the launch disk. It is *not intended* to transfer PC disks or other software that must be run under the guest OS.

An appropriate utility `send.pl` is provided that sends a file in the format required by `recv.exe`.

To transfer a file, connect the computers with a serial cable, launch the host OS and on the PC use the command:

```
send.pl file_to_send
```

Then on the host OS type the command:

```
recv file_to_receive
```

The file will be transferred to the Commodore and saved on the disk. Beware that you *must* launch the send command on the PC first, otherwise `recv.exe` will hang waiting for the first handshake from the sender side.

Note that the host system is on a 8050 diskette; if you have a 8250 drive, you must first switch it to the 8050 mode before booting the host OS; otherwise writing to the diskette will not be possible. Alternatively, you can use the `format` command to format a new MS-DOS disk in the drive 1 (accessed as drive B: under MS-DOS).


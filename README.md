# PC emulation layer

This software allows you to run IBM PC software on a Commodore 710 equipped with the 8088 card. The card has a dedicated MS-DOS 1.25 port that runs on it, but there is very little software that could be used.

The aim of the project is to emulate as much of the PC architecture in software, to allow booting PC versions of MS-DOS and run PC software.


## Quick start guide

Use `cbmlink` (or other tool) to create two Commdore disks:

 * `launch.d80` is the native version of MS-DOS 1.25 designed to run on CBM-II software. It serves as the launchpad for the emulation layer.
 * `msdos330.d80` is the image created from a 360 kB PC diskette containing PC-DOS 3.30.

Insert the first diskette in the drive 0 and hit Shift+Run to start MS-DOS. After the system loads, issue the following commands:

```
pc-high
reboot
```

The first command loads the emulation layer in the upper part of the memory, and the second issues INT 19 to reboot the 8088 system.

Inser the second diskette in the drive 0 and press any key. The emulation layer will load the PC boot sector and execute it, loading the PC version of MS-DOS. Beware: loading the system takes about 2 minutes, due to slow speed of the IEEE drive.

Loaded PC-DOS 3.30 runs inside the PC emulation layer. You can try different DOS commands - everyhing that is not tied directly to PC hardware (like GRAFTABL) should work.

## How does it work?

The emulation layer consists of two main modules:

 * High-level interrupt emulation routines, implementing part of the PC BIOS interrupts. This part is located in the *int.asm* file.
 * Low-level I/O routines, which interface to the 6509 processor and I/O services provided by it. This part is located in the *ipc.asm* file.

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
* INT 1A - function 00 only

These services are sufficient to run MS-DOS and other software which does not rely on accessing PC hardware directly.

PC disk access is possible with the 8050 or 8250 drive; a script converting IMG files to D80 or D82 images is provided. These images need to be written to the Commodore diskette using software such as `cbmlink` - CBM drives cannot read PC disks directly due to different format (MFM vs GCR).

Additionally, the low-level routines emulate INT 08 and INT 1C using the 500 Hz timer of the CBM-II (this is important for software containing timing loops).

### What is not emulated?

PC hardware that doesn't exist in the CBM-II cannot be emulated. The most important part is video memory - if the software accesses the video memory directly, it will not work (unfortunately, lots of software does that). Similarly, software that relies on keyboard interrupts, accesses I/O ports, etc will not work. 

Interrupt routines from IBM AT upwards are not emulated, except for a few functions of INT 13. This should not be needed, as the card has an 8088 processor so could not pass for an AT anyway.

BIOS data area at segment 0040 is not emulated - this area is used for IPC calls to the 6509 processor.

### How can it be used?

Currently the emulation layer requires booting the native version of MS-DOS first, because it relies on the 6509 portion of it providing I/O routines. Work is underway to place the layer directly in the ROM of the card, so that it could be started without any host environment.

There are two main versions of the emulation layer:

* `pc-tsr` loads itself as a TSR in the MS-DOS 1.25 system. This allows running PC programs inside native Commodore MS-DOS (if you are lucky enough to find programs that work with such ancient version of MS-DOS).
* `pc-high` loads itself in the highest 8 kB of the memory, and can function stand-alone. It can be used to boot other operating systems; it also provides greater level of compatilbility (for example, it emulates INT 08 timer interrupt, which is impossible in the native MS-DOS).

In order to use PC software, it must be transferred to the Commodore disk using the `imager.pl` utility (described below).

### What software does work?

Currently I am concentrating on booting PC version of MS-DOS and making it work. Once MS-DOS runs without problems, I plan to start testing various other software. Suggestions are welcome on what to try first.

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

The native MS-DOS 1.25 contains a file `recv.exe` that can be used to transmit files from a PC to the host disk over a RS-232 connection. You can use this tool to transfer recompiled emulation layer files to the launch disk. It is *not intended* to transfer PC disks or other software that must be run under the guest OS.

An appropriate utility `send.pl` is provided that sends a file in the format required by `recv.exe`.

To transfer a file, connect the computers with a serial cable, launch the host OS and type the command:

```
recv file_to_receive
```

Then on the PC, use the command:

```
send.pl file_to_send
```

The file will be transferred to the Commodore and saved on the disk.

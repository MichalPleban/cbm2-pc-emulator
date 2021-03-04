# CBM-II PC emulation layer

## Warning!

Starting with the 0.8.0 release, the software is meant to work on the new 8088 CPU board:

https://github.com/MichalPleban/cbm2-8088-ram-board

If you want to use the original 8088 board, you need the latest 0.7x release. Please note that new features are only added to the 0.8 branch.

More information about the project can be found at:

http://www.cbm-ii.com/

## About the project

This software allows you to run IBM PC software on a Commodore CBM-II (such as 710 or 610) equipped with the 8088 card. The card has a dedicated MS-DOS 1.25 port that runs on it, but there is very little software that could be used with that old version. The aim of the project is to emulate as much of the PC architecture in software as possible, to allow booting PC versions of MS-DOS and running PC software. Currently modern versions of MS-DOS and FreeDOS are booting on the card without any problems.

A PC-compatible font is also supplied, allowing to display characters that are not present in the PETSCII character set (such as \ | {} or CP437 graphics characters).

## How does it work?

The PC compatibility software layer works on the hardware 8088 card and contains routines that emulate the PC BIOS and other aspects of the PC architecture to achieve a high degree of PC compatibility. The software consists of the following functional parts:

### PC BIOS emulation

The software contains around 40 BIOS functions of INT 10h, INT 13h, INT 16h and so on (see the table below complete list). The functions serve as a bridge between the PC BIOS interface and the IPC library that runs on the 6509 CPU. For example, INT 16h function 00h (read from keyboard buffer) is implemented as a wrapper for the IPC library function $11, which in turn calls the GETIN function in the Commodore KERNAL to read the input buffer. 

Some BIOS functions are simple wrappers like that, while others require more sophisticated processing. For example, INT 13h functions are used to simulate a PC disk drive with an 8050 or 8250 Commodore drive. This requires sector position recalculation because the PC disk geometry is vastly different than that of the 8050, plus simulating 512 byte PC disk sectors with two 256 byte Commodore disk sectors.

Additionally, an 18.2 Hz timer interrupt is implemented on INT 8 just like on the PC, by programming the CIA timers A and B to generate a square wave. Because the IRQs are assigned differently on the 8088 card than on the PC (for example, the timer interrupt is IRQ0 on the PC but IRQ7 on the card), the interrupt vectors are remapped into INT 50h-57h and code was added to call appropriate PC interrupt vectors from IRQ handler routines.

### Video memory emulation

Most PC software does not use BIOS for screen output, because direct manipulation of the video memory at segment 0B000h is much faster. To maintain compatibility with these applications, a software emulation of video memory was added which periodically copies the contents of this memory area into the Commodore video memory at $D000. 

This routine is run periodically when the CPU is idle, for example waiting for keyboard input. It converts the PC video characters into appropriate PETSCII equivalents and sets the reverse bit according to the character attributes, thus emulating an MDA text adapter closely. A hardware latch register was added to the board, which latches bits when a specific region of the video memory is written by the CPU; this way, the routine works much faster because it can refresh only the modified screen regions.

### Hardware virtualization

To allow compatibility with PC applications that access the PC hardware directly, the concept of hardware virtualization was created. It works as follows: whenever the applications tries to access a hardware device using IN or OUT instructions, a NMI interrupt is generated. The address if the I/O port is latched, so that the NMI handler routine can see which hardware device is being accessed. It can then perform necessary actions to simulate the workings of this hardware device.

As an example, an emulation of the PC speaker was created by hooking up code on accesses to ports 41h and 61h. This code checks the frequency of the sound that’s being generated and uses the specifically created IPC $1D function which programs the SID chip on the Commodore side to play the same sound.

### Card hardware support

The card contains several hardware features that need software support, for example:
-	The SPI interface is used to attach a memory card. This card is visible to the PC applications via the INT 13h interface as an 8 GB hard disk, which can be used to boot DOS.
-	The I2C interface is used to attach a real time clock, which is visible to the PC applications via the INT 1Ah interface.
-	The card configuration registers are used to select the system clock frequency. The card boots with the 8 MHz clock, but if the NEC V20 processor is detected, it is switched to faster 12 MHz clock.

The software also re-implements a portion of the original Commodore KERNAL to fix a race condition bug which occurs when the RS-232 port is being used with the card.

## What is emulated?

The emulation layer presents itself to the applicatins as an IBM PC with a MDA graphics card, one serial and one parallel port. It provides the following services, which are sufficient to run MS-DOS and other PC software which does not rely on accessing PC hardware directly.

### BIOS interrupts

The following BIOS functions are provided by the software:

* INT 10 - functions 00, 02, 03, 05, 06, 07, 09, 0A, 0E, 0F
* INT 11
* INT 12
* INT 13 - functions 00, 01, 02, 03, 04, 08, 0C, 0D, 10, 15, 16
* INT 14 - functions 00, 01, 02, 03
* INT 16 - functions 00, 01, 02
* INT 17 - functions 00, 01, 02
* INT 18
* INT 19
* INT 1A - functions 00, 01, 02, 03, 04, 05

### Disk access

A 8GB hard drive is emulated using the SD memory card. The card is formatted using the FAT filesystem, which allows using it in a Windows or Max computer to transfer files. Note that the SD card must be first reformatted to conform to the INT 13h CHS geometry used by the card. The attached `freedos.zip` file contains an SD card image that can be transferred to a fresh card; it contains a proper boot sector and partition table so that the card can be used immediately.

PC diskette access is also possible with the 8050 or 8250 drive; a script converting IMG files to D80 or D82 images is provided. These images need to be written to the Commodore diskette using software such as `cbmlink` - CBM drives cannot read PC disks directly due to different format (MFM vs GCR).

### Video memory emulation

A routine copies the contents of MDA video memory from segment 0B000h to Commodore video memory at $D000, with appropriate CP437 to PETSCII conversion. This routine is run periodically so that the changes made to the video memory by the running application are reflected on the screen.

### Timer interrupts

The low-level routines emulate INT 08 and INT 1C using CIA timers of the CBM-II  - this is important for software containing timing loops.

### BIOS data area

Several entries of the BIOS data area at segment 0040h are emulated, such as current video mode or Shift key flags, to support software that uses these variables directly.

### Virtual hardware

A framework for emulating hardware devices in software is present. At the moment the only supported device is PC Speaker, which is emulated using the SID chip.

## Compiling the software

The following tools are required to successfully build the system:

 * GNU make.
 * NASM (Netwide Assembler) - to compile the 8088 code. 
 * CA65 assembler - to compile the 6509 code.
 * Perl - to run disk imaging utilities.
 * c1541 (for example, from your VICE distribution) - to place compiled files in D80 and D82 images.

The compiled files are placed in the `dist` directory.

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

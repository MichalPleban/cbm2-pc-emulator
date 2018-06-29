
%undef ROM
%undef STANDALONE

[BITS 16]
[CPU 8086]

[ORG 0x0100]
[SECTION .text]

; Starting offest of the resident code.
Install_Start equ ($-$$)

; Number of bytes to leave from the top of memory.
; to make room for MS-DOS 1.25 COMMAND.COM portion.
Install_Leave equ 1800h

			call Install_High
			int 20h
						
%include 'src/8088/include/debug.asm'
%include 'src/8088/include/ipc.asm'
%include 'src/8088/include/int.asm'
%include 'src/8088/include/init.asm'
%include 'src/8088/include/data.asm'

Init_Far:
			call Init_INT
			retf

; Installable code ends here.
Install_End:

%include 'src/8088/include/install.asm'
%include 'src/8088/include/version.asm'
			


%undef ROM
%define STANDALONE

[BITS 16]

[ORG 0xFFFE]
[SECTION .text]

; Commodore PRG load address (0050:0000)
			dw 0500h
			
			jmp Do_Install
			times 10-($-$$) db 0
			
; Value 0 at offset 0008h ensures cold start.
			dw 0

Do_Install:
			; Check if the ROM contains current version
			mov bx, 0F000h
			mov es, bx
			cmp [es:0FFFAh], word "PC"
			jne Do_Install_RAM
			cmp [es:0FFFCh], word VERSION_NUMBER
			jb Do_Install_RAM
			jmp 0F000h:0FFF5h

Do_Install_RAM:
			; Install IPC table at segment 0040h.
			mov bx, 0040h
			call IPC_Install
			call IPC_Reset
			call Install_High
Do_Install_Loop:
			int 19h
			jmp Do_Install_Loop

%include 'src/8088/include/install.asm'
%include 'src/8088/include/version.asm'

			times 0102h-($-$$) db 0
			
; Starting offest of the resident code.
Install_Start equ ($-$$)-2

; Number of bytes to leave from the top of memory (none).
Install_Leave equ 0

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



[CPU 8086]

%define STANDALONE
%define ROM
%define BIG
%define SD
%define SCREEN

			org	00000h
			
			jmp 0F000h:0F000h

			times 0008h-($-$$) db 0FFh
			jmp HDROM_Handle
			times 000Ch-($-$$) db 0FFh
			dw 0F001h
			dw "HD"
			
incbin 'src/disk/hd.bin'

%include 'src/8088/include/hdrom.asm'
%include 'src/8088/include/sd.asm'
%include 'src/8088/include/screen.asm'
%include 'src/8088/include/version.asm'
%include 'src/8088/include/data.asm'
%include 'src/8088/include/debug.asm'
%include 'src/8088/include/init.asm'
	
			times 0F000h-($-$$) db 0FFh

RomStart:
		
%include 'src/8088/include/rom_8255.asm'

RomEnd:

RomInit:
			call IPC_Install
			call IPC_Reset
			call Init_Data
			call Init_CheckMem
			call Init_INT
			call Screen_Init
			xor ah, ah
			int 10h
			call Version_Output
RomLoop:
			int 19h
			jmp RomLoop
		
%include 'src/8088/include/int.asm'
%include 'src/8088/include/ipc.asm'

			times 0FFF0h-($-$$) db 0FFh
	
	
			jmp	0F000h:startf
			jmp	0F000h:RomInit
	
			times 0FFFAh-($-$$) db 0FFh
			
			dw "PC"
			dw VERSION_NUMBER
			
			dw 0FFFFh




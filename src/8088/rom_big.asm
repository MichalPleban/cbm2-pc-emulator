
%define STANDALONE
%define ROM
%define BIG

			org	00000h
			
			jmp 0F000h:0F000h

			times 0008h-($-$$) db 0FFh
			jmp HDROM_Handle
			times 000Ch-($-$$) db 0FFh
			dw 0F001h
			dw "HD"
			
incbin 'src/disk/hd.bin'

%include 'src/8088/include/hdrom.asm'
	
			times 0F000h-($-$$) db 0FFh

RomStart:
		
%include 'src/8088/include/rom.asm'

RomEnd:

RomInit:
			mov bx, 0040h
			call IPC_Install
			call IPC_Reset
			call Init_Data
			call Init_CheckMem
			call Init_INT
			xor ah, ah
			int 10h
			mov ax, Data_Segment
			mov es, ax
			push cs
			pop ds
			mov si, Version_Banner
			call Output_String
RomLoop:
			int 19h
			jmp RomLoop
		
%include 'src/8088/include/version.asm'
%include 'src/8088/include/debug.asm'
%include 'src/8088/include/ipc.asm'
%include 'src/8088/include/int.asm'
%include 'src/8088/include/init.asm'
%include 'src/8088/include/data.asm'

			times 0FFF0h-($-$$) db 0FFh
	
	
			jmp	0F000h:startf
			jmp	0F000h:RomInit
	
			times 0FFFAh-($-$$) db 0FFh
			
			dw "PC"
			dw VERSION_NUMBER
			
			dw 0FFFFh




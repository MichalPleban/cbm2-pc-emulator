
[CPU 8086]

%define ROM

			org	00000h
			
			jmp 0F000h:0F000h

RomInit:
			call IPC_Install
			call IPC_Reset
			call Init_Data
			call Init_INT
			call Screen_Init
			xor ah, ah
			int 10h
			call Version_Output
RomLoop:
			int 19h
			jmp RomLoop

%include 'src/8088/include/init.asm'
%include 'src/8088/include/sd.asm'
%include 'src/8088/include/i2c.asm'
%include 'src/8088/include/debug.asm'
%include 'src/8088/include/version.asm'
%include 'src/8088/include/data.asm'
%include 'src/8088/include/ipc.asm'
%include 'src/8088/include/screen.asm'
%include 'src/8088/include/int.asm'
	

			times 0F000h-($-$$) db 0FFh

RomStart:
		
%include 'src/8088/include/rom.asm'

RomEnd:
		
			times 0FFF0h-($-$$) db 0FFh	
	
			jmp	0F000h:startf
			jmp	0F000h:RomInit
	
			times 0FFFAh-($-$$) db 0FFh
			
			dw "PC"
			dw VERSION_NUMBER
			
			dw 0FFFFh




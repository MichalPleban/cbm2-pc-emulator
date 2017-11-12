

		org	0E000h

		times 4096 db 0FFh

RomStart:
		
%include 'src/8088/include/rom.asm'

RomEnd:

		times 8176-($-$$) db 0FFh


		jmp	0F000h:startf


		times 11 db 0FFh





%include 'src/defs.inc'

;%define DEBUG

[BITS 16]

[ORG 0x0100]
[SECTION .text]

			call Init_Data
			call Init_CheckMem
			call Init_INT
			xor ah, ah
			int 10h
			
			call Finish
			int 20h
						
%include 'src/include/debug.asm'
%include 'src/include/ipc.asm'
%include 'src/include/int.asm'
%include 'src/include/data.asm'

EndResident:

%include 'src/include/init.asm'

Finish:
			mov ah, 09h
			mov dx, FinishBanner
			int 21h
			mov dx, EndResident
			int 27h
			ret
FinishBanner:
			db "IBM PC Compatibility layer v", VERSION, " installed.", 10, 13, '$'
			
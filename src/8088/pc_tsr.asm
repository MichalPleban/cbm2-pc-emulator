
%include 'src/8088/defs.inc'

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
						
%include 'src/8088/include/debug.asm'
%include 'src/8088/include/ipc.asm'
%include 'src/8088/include/int.asm'
%include 'src/8088/include/data.asm'

EndResident:

%include 'src/8088/include/init.asm'

Finish:
			mov ah, 09h
			mov dx, FinishBanner
			int 21h
			mov dx, EndResident
			int 27h
			ret
FinishBanner:
			db "IBM PC Compatibility layer v", VERSION, " installed.", 10, 13, '$'
			
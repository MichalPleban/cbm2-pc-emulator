
%define VERSION		"0.30"

[BITS 16]

[ORG 0x0100]
[SECTION .text]

			call Install
			xor ah, ah
			int 10h
			call Finish
			int 20h
						
%include 'src/include/ipc.asm'
%include 'src/include/int.asm'
%include 'src/include/install.asm'
%include 'src/include/data.asm'

EndResident:

Finish:
			mov ah, 09h
			mov dx, FinishBanner
			int 21h
			mov dx, EndResident
			int 27h
			ret
FinishBanner:
			db "IBM BC Compatibility layer v", VERSION, " installed.", 10, 13, '$'
			

[BITS 16]

[ORG 0x0100]
[SECTION .text]

			xor ax, ax
			mov es, ax
			test [es:0066h], word 0FFFFh
			jz NotInstalled
			xor ah, ah
			int 10h
			int 20h
NotInstalled:
			mov dx, MessageError
			mov ah, 09h
			int 21h
			int 20h
MessageError:
			db "Error: PC compatibility layer not installed.", 0Ah, 0Dh, "$"


[BITS 16]

[ORG 0x0100]
[SECTION .text]

			xor ax, ax
			mov es, ax
			test [es:0066h], word 0FFFFh
			jz NotInstalled
			mov dx, MessageOK
			mov ah, 09h
			int 21h
NoInput:
			mov dl, 0FFh
			mov ah, 06h
			int 21h
			jz NoInput
			int 19h
			int 20h
NotInstalled:
			mov dx, MessageError
			mov ah, 09h
			int 21h
			int 20h
MessageOK:
			db "Insert a bootable PC disk and press any key.", 0Ah, 0Dh, "$"
MessageError:
			db "Error: PC compatibility layer not installed.", 0Ah, 0Dh, "$"

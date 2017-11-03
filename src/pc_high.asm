
%include 'src/defs.inc'

; Number of bytes to leave from the top of memory.
; to make room for MS-DOS 1.25 COMMAND.COM portion.
%define Install_Leave		1800h

[BITS 16]

[ORG 0x0100]
[SECTION .text]

			call Finish
			int 20h
						
%include 'src/include/debug.asm'
%include 'src/include/ipc.asm'
%include 'src/include/int.asm'
%include 'src/include/init.asm'
%include 'src/include/data.asm'

Init_Far:
			call Init_INT
			retf

EndResident:

Finish:
			call Init_Data
			call Init_CheckMem

			; Calculate the highest segment where the software will fit.
			mov dx, EndResident-0100h
			mov bx, dx
			add bx, Install_Leave
			mov cl, 4
			shr bx, cl
			inc bx
			push ds
			mov ax, Data_Segment
			mov ds, ax
			mov ax, [Data_MemSize]
			sub ax, bx

			; Decrease memory size reported by INT 12
			mov cx, ax
			and cx, 0FF00h 
			mov [Data_MemSize], cx
			pop ds
						
			; Move the software to the upper location
			sub ax, 10h
			mov es, ax
			mov [FinishVector+2], ax
			mov di, 0100h
			mov si, di
			mov cx, dx
			rep movsb
									
			; Install software
			call far [FinishVector]
			
			; Output banner
			xor ah, ah
			int 10h
			mov ax, Data_Segment
			mov es, ax
			push cs
			pop ds
			mov si, FinishBanner
			call Output_String
			
			ret

FinishBanner:
			db "IBM PC Compatibility layer v", VERSION, " installed.", 10, 13, 0
			
FinishVector:
			dw Init_Far
			dw 0

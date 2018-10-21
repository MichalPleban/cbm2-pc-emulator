
; -----------------------------------------------------------------
; Installs the software in the upper part of the memory.
; Assumes that the code to be installed starts at offset 0100h.
; -----------------------------------------------------------------

Install_High:

			call Init_Data
			call Init_CheckMem

			; Calculate the highest segment where the software will fit.
			mov dx, Install_End - Install_Start
			mov bx, dx
			add bx, Install_Leave
			call Install_Check
            jz Install_High_0
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
Install_High_0:
			mov [FinishVector+2], ax
			mov di, Install_Start
			mov si, di
			mov cx, dx
			rep movsb
									
			; Install software
			call far [FinishVector]
			
			; Output banner
			xor ah, ah
			int 10h
			call Version_Output
			
			ret

FinishVector:
			dw Init_Far
			dw 0

; -----------------------------------------------------------------
; Checks if the library can be copied to the video memory.
; -----------------------------------------------------------------

Install_Check:
			mov ax, 0B100h
			mov es, ax
			mov cx, 0A55Ah
			mov [es:bx], cx
			cmp cx, [es:bx]
			jnz Install_Check_Fail
			neg cx
			mov [es:bx], cx
			cmp cx, [es:bx]
Install_Check_Fail:
            ret

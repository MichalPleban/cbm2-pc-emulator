
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
			mov di, Install_Start
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
			mov si, Version_Banner
			call Output_String
			
			ret

FinishVector:
			dw Init_Far
			dw 0

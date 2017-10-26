

; -----------------------------------------------------------------
; Install interrupt vectors
; -----------------------------------------------------------------

Install:
			cld
			
			; Write interrupt vectors
			mov ax, cs
			mov ds, ax
			mov si, Install_Table
			xor bx, bx
			mov es, bx
			mov di, 0040h
			mov cx, (Install_Table_End-Install_Table)/2
Install_0:
			movsw
			stosw
			loop Install_0
			
			; Zero the data segment
			mov ax, Data_Segment
			mov es, ax
			xor ax, ax
			mov di, ax
			mov cx, Data_Length
			rep stosb
			
			ret

; -----------------------------------------------------------------
; Interrupt vector table
; -----------------------------------------------------------------

Install_Table:
			dw INT_10
			dw INT_11
			dw INT_12
			dw INT_13
			dw INT_14
			dw INT_15
			dw INT_16
			dw INT_17
			dw INT_18
			dw INT_19
			dw INT_1A
			dw INT_1B
			dw INT_1C
			dw 0
			dw INT_1E
			dw 0
Install_Table_End:

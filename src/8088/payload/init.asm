

; -----------------------------------------------------------------
; Init interrupt vectors
; -----------------------------------------------------------------

Init_INT:
			cld
			
			; Write interrupt vectors
			mov ax, cs
			mov ds, ax
			mov si, Init_INT_Table
			xor bx, bx
			mov es, bx
			mov di, 0040h
			mov cx, (Init_INT_Table_End-Init_INT_Table)/2
Init_INT_0:
			movsw
			stosw
			loop Init_INT_0
			
			ret

; -----------------------------------------------------------------
; Init data segment
; -----------------------------------------------------------------

Init_Data:
			; Zero the data segment
			mov ax, Data_Segment
			mov es, ax
			xor ax, ax
			mov di, ax
			
			; Cursor position
			stosw
			dec ax
			stosw
			
			; Disk drive parameters
			mov al, 2
			stosb
			mov al, 9
			stosb
			mov al, 2
			stosb
			
			; Debug flag
			xor ax, ax
			stosb
			
			; Memory size
            add di, 2
            
            ; Tick count
            stosw
            
            ; Boot flag
            stosb

            ; SD presence flag
            stosb

            ; Video refresh counter
            stosb
            
            ; Active video page
            stosb
            
			ret
			
			
; -----------------------------------------------------------------
; Interrupt vector table
; -----------------------------------------------------------------

Init_INT_Table:
			dw Screen_INT
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
Init_INT_Table_End:

; -----------------------------------------------------------------
; Output zero-terminated string.
; Input:
;			DS:SI - pointer to the string
; -----------------------------------------------------------------

Output_String:
			lodsb
			test al, al
			jz Output_String_End
			mov ah, 0Eh
			int 10h
			jmp Output_String
Output_String_End:
			ret

%ifndef ROM

; -----------------------------------------------------------------
; Installs the software in the upper part of the memory.
; -----------------------------------------------------------------

Install_High:

			call Init_Data

			; Calculate the highest segment where the software will fit.
			mov dx, Install_End - Install_Start
			mov bx, dx
			add bx, Install_Leave
			mov ax, 0E000h
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
			call Version_Output
			
			ret

FinishVector:
			dw Init_Far
			dw 0

%endif


Version_Banner:
			db "PC Compatibility layer build ", SOFTWARE_VERSION, SOFTWARE_BUILDS, " "
			db "(C) 2017-2019 Micha", 9Ch, " Pleban", 10, 13, 0, '$'

Version_Output:
   			mov ax, Data_Segment
			mov es, ax
			push cs
			pop ds
			mov si, Version_Banner
			call Output_String
			ret




; -----------------------------------------------------------------
; Init interrupt vectors
; -----------------------------------------------------------------

Init_INT:
			cld
			
			; Write interrupt vectors
			mov ax, cs
			mov ds, ax
			xor bx, bx
			mov es, bx
			
			mov si, Init_INT_Table
			mov di, 0040h
			mov cx, (Init_INT_Table_End-Init_INT_Table)/2
Init_INT_0:
			movsw
			stosw
			loop Init_INT_0

			mov si, Init_INT_Table2
			mov di, 0300h
			mov cx, (Init_INT_Table2_End-Init_INT_Table2)/2
Init_INT_1:
			movsw
			stosw
			loop Init_INT_1
			
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
			
			xor ax, ax
			; Cursor visibilty
			stosb
			stosw
			
			; Debug flag
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

Init_INT_Table2:
			dw INT_C0
			dw INT_C1
Init_INT_Table2_End:

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


; -----------------------------------------------------------------
; Output a horizontal line.
; -----------------------------------------------------------------

Output_Line:
            mov al, 0C4h
            mov ah, 0Eh
            mov cx, 80
Output_Line1:            
            int 10h
            loop Output_Line1
            ret

; -----------------------------------------------------------------
; Output the version banner.
; -----------------------------------------------------------------

Version_Banner:
			db "PC Compatibility layer build ", SOFTWARE_VERSION, SOFTWARE_BUILDS, " "
			db "(C) 2017-2022 Micha", 9Ch, " Pleban", 10, 13, 0, '$'

Version_Output:
   			mov ax, Data_Segment
			mov es, ax
			push cs
			pop ds
			mov si, Version_Banner
			call Output_String
			ret


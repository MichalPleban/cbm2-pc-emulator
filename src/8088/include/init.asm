

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
            
			ret

; -----------------------------------------------------------------
; Calculate memory size
; -----------------------------------------------------------------

Init_CheckMem:
			push ds
			mov bx, 00FFh
			mov ax, 5AA5h
Init_CheckMemLoop:
			mov ds, bx			
			mov cx, [000Eh]
			mov [000Eh], ax
			cmp [000Eh], ax
			jne Init_CheckMemFinish
			xchg al, ah
			mov [000Eh], ax
			cmp [000Eh], ax
			jne Init_CheckMemFinish
			mov [000Eh], cx
			add bx, 00100h
			cmp bx, 0B000h
			jb Init_CheckMemLoop
Init_CheckMemFinish:	
			and bx, 0FF00h
			mov ax, Data_Segment
			mov ds, ax
			mov [Data_MemSize], bx
			pop ds
			ret
			
			
; -----------------------------------------------------------------
; Interrupt vector table
; -----------------------------------------------------------------

Init_INT_Table:
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


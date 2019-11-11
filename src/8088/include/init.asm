

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
			
%ifdef I2C
            call Init_RTC
%endif
			
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


; -----------------------------------------------------------------
; Copy time from the RTC chip to the tick count.
; -----------------------------------------------------------------

%ifdef I2C
Init_RTC:
            push ax
            
            ; Load time from the RTC
            call INT_1A_02_Do
            jc Init_RTC_1
            mov al, dh
            call ConvertFromBCD
            mov ah, al          ; AH = Seconds
			mov al, cl
			call ConvertFromBCD
			mov dl, al          ; DL = Minutes
			mov al, ch
			call ConvertFromBCD
			mov dh, al          ; DH = Hours
			xor al, al          ; AL = Microseconds
			
			push ax
			push dx
			call IPC_TimeSet
			pop dx
			pop ax
			
			mov bl, dh          ; BL = Hours
			mov al, ah          ; AL = Minutes
			mov dh, al          ; DH = Seconds
			
			xor ah, ah
			mov cl, 60
			mul cl              ; AX = minutes * 60
			add al, dh
			adc ah, 0           ; AX = minutes * 60 + seconds
			push ax
			xor dx, dx
			mov cx, 5
			div cx              ; AX = (minutes * 60 + seconds) * 0.2
			mov dx, ax
            pop ax
            mov ch, ah			
			mov cl, 18
			mul cl              ; AX = (minutes * 60 + seconds) * 18
			add dx, ax          
			mov al, ch
			mul cl
			add dh, al          ; DX = (minutes * 60 + seconds) * 18.2
			
			xor bh, bh
			push ds
			xor ax, ax
			mov ds, ax
			mov [046Ch], dx
			mov [046Eh], bx
			pop ds
			
Init_RTC_1:
            pop ax
            ret
%endif



; --------------------------------------------------------------------------------------
; Check if the screen conversion memory is installed.
; --------------------------------------------------------------------------------------

Screen_Init:
            call IPC_Video_Init
            cmp al, 0FFh
            jnz Screen_Init_0
            push ds
            push ax
            mov ax, Screen_Segment
            mov ds, ax
            mov [0FFEh], dx
            xor ax, ax
            mov ds, ax
            mov [0040h], word Screen_INT
            mov ax, cs
            mov [0042h], ax
            call Screen_INT_00
            pop ax
            pop ds
Screen_Init_0:
            ret

; --------------------------------------------------------------------------------------
; Display information about screen memory emulation.
; --------------------------------------------------------------------------------------

Screen_ShowInfo:
            push ds
            push ax
            push dx
            xor ax, ax
            mov ds, ax
            cmp [0040h], word Screen_INT
            jne Screen_ShowInfo_0
            mov ax, Screen_Segment
            mov ds, ax
            mov dx, [0FFEh]
            push cs
            pop ds
            mov si, Screen_Banner1
            call Output_String
            mov al, dl
            and al, 0Fh
            call Screen_Hex
            mov al, dh
            shr al, 1
            shr al, 1
            shr al, 1
            shr al, 1
            call Screen_Hex
            push cs
            pop ds
            mov si, Screen_Banner2
            call Output_String
Screen_ShowInfo_0:
            pop dx
            pop ax
            pop ds
            ret

Screen_Banner1:
            db "Video memory buffer at $", 0
Screen_Banner2:
            db "000", 13, 10, 0

Screen_Hex:
			add al, 30h
			cmp al, 39h
			jbe Screen_Hex1
			add al, 7
Screen_Hex1:
            jmp Screen_INT_0E

; -----------------------------------------------------------------
; INT 10 - screen functions.
; -----------------------------------------------------------------

Screen_INT:
			cmp ah, 0Fh
			ja Screen_INT_Ret
			push bp
			push es
			mov bp, Data_Segment
			mov es, bp
			mov bp, Screen_INT_Functions
			push ds
			call INT_Dispatch
			pop ds
			pop es
			pop bp
Screen_INT_Ret:
			iret

Screen_INT_Functions:
			dw Screen_INT_00
			dw INT_Unimplemented
			dw Screen_INT_02
			dw Screen_INT_03
			dw INT_Unimplemented
			dw INT_Unimplemented
			dw Screen_INT_06
			dw Screen_INT_07
			dw INT_Unimplemented
			dw Screen_INT_09
			dw Screen_INT_0A
			dw INT_Unimplemented
			dw INT_Unimplemented
			dw INT_Unimplemented
			dw Screen_INT_0E
			dw Screen_INT_0F
			
			
; -----------------------------------------------------------------
; Check whether the video memory needs refreshing.
; -----------------------------------------------------------------

Screen_Interrupt:
			push ds
			push ax
			mov ax, Data_Segment
			mov ds, ax
			inc byte [Data_Refresh]
            cmp byte [Data_Refresh], 50
            jb Screen_interrupt_NoRefresh
            call Screen_Refresh
Screen_interrupt_NoRefresh:
            pop ax
            pop ds
            ret
            
; -----------------------------------------------------------------
; Refresh the screen by copying it from the RAM to video memory.
; -----------------------------------------------------------------

Screen_Refresh:
            push dx
            mov byte [Data_Refresh], 00h
            mov dx, [Data_CursorVirtual]
            call IPC_Video_Convert
            pop dx
            ret
			
; -----------------------------------------------------------------
; INT 10 function 00 - set video mode.
; Clears the screen and re-positions the cursor.
; -----------------------------------------------------------------
			
Screen_INT_00:
            push ax
            call Screen_Segments
            xor ax, ax
			mov [Data_CursorVirtual], ax
			mov [Data_CursorPhysical], ax
			call Screen_Clear
			pop ax 
            ret

; -----------------------------------------------------------------
; INT 10 function 02 - set cursor position
; -----------------------------------------------------------------
			
Screen_INT_02:
            push ax
            mov ax, Data_Segment
            mov ds, ax

			; MS BASIC Compiler runtime calls this function with DX=FFFF ?
            test dx, 8080h
			jnz Screen_INT_02_Ret

			; Check if row and column are within allowed bounds
			cmp dh, 24
			jl Screen_INT_02_RowOK
			mov dh, 23
Screen_INT_02_RowOK:
			cmp dl, 80
			jl Screen_INT_02_ColumnOK
			mov dl, 79
Screen_INT_02_ColumnOK:
            mov [Data_CursorVirtual], dx
            call Screen_CursorCalc
            
Screen_INT_02_Ret:
            pop ax
            ret

; -----------------------------------------------------------------
; INT 10 function 03 - get cursor position
; -----------------------------------------------------------------
			
Screen_INT_03:
            mov dx, Data_Segment
            mov ds, dx
            mov dx, [Data_CursorVirtual]
            ret
            
; -----------------------------------------------------------------
; INT 10 function 06 - scroll screen up
; -----------------------------------------------------------------

Screen_INT_06:
;            db 0CCh
            call Screen_ScrollCalc
            call Screen_ScrollPerform
            ret            

Screen_ScrollCalc:
            mov bx, dx
            
            ; BL - number of columns in the window
            sub bl, cl
            inc bl
            ; BH - number of rows in the window
            sub bh, ch
            inc bh
            
            ; DH - number of rows to shift
            test al, al
            jz Screen_ScrollCalc_1
            cmp al, bh
            jb Screen_ScrollCalc_2
Screen_ScrollCalc_1:
            mov al, bh
Screen_ScrollCalc_2:
            mov dh, al
            
            ; DL - number of bytes to skip in each line
            mov dl, 160
            sub dl, bl
            sub dl, bl
            
            ; DI - destination address
            mov al, ch
            xor ah, ah
            mov ch, 160
            mul ch
            add al, cl
            adc ah, 0
            add al, cl
            adc ah, 0
            mov di, ax
            
            ; SI - source address
            mov si, di
            mov al, dh
            xor ah, ah
            mul ch
            add si, ax

            ; DS, ES - screen segment
            mov cx, Screen_Segment
            mov es, cx
            mov ds, cx
            
            xor cx, cx
            ret
            
Screen_ScrollPerform:
            cmp dh, bh
            jae Screen_ScrollClear
            mov cl, bl
            rep movsw
            mov cl, dl
            add si, cx
            add di, cx
            dec bh
            jmp Screen_ScrollPerform
Screen_ScrollClear:
            mov cl, bl
            mov ax, 0020h
            rep stosw
            mov cl, dl
            add di, cx
            dec bh
            jnz Screen_ScrollClear
            ret
            
            
            
; -----------------------------------------------------------------
; INT 10 function 07 - scroll screen down
; -----------------------------------------------------------------

Screen_INT_07:
            push ax
            call Screen_Segments
            pop ax
			test al, al
			jz Screen_INT_07_Clear
            ret

Screen_INT_07_Clear:
            jmp Screen_Clear

; -----------------------------------------------------------------
; INT 10 function 09 - write character and attribute.
; -----------------------------------------------------------------

Screen_INT_09:
            push di
            push ax
            call Screen_Segments
			mov di, [Data_CursorPhysical]
			pop ax
			stosw
			pop di
            ret
            
; -----------------------------------------------------------------
; INT 10 function 0A - write character only.
; -----------------------------------------------------------------

Screen_INT_0A:
            push di
            push ax
            call Screen_Segments
			mov di, [Data_CursorPhysical]
			pop ax
			stosb
			pop di
            ret

; -----------------------------------------------------------------
; INT 10 function 0E - teletype output.
; -----------------------------------------------------------------

Screen_INT_0E:
			call INT_ClearDot

            push di
            push ax
            call Screen_Segments
			mov di, [Data_CursorPhysical]
			pop ax
			push ax
			cmp al, 20h
			jl Screen_INT_0E_Control			
Screen_INT_0E_Output:			
			stosb
			xor al, al
			stosb
			mov [Data_CursorPhysical], di
			mov al, [Data_CursorVirtual]
			inc al
			cmp al, 80
			jnz Screen_INT_0E_End
			xor al, al
			inc byte [Data_CursorVirtual+1]
Screen_INT_0E_End:
			mov [Data_CursorVirtual], al
			call Screen_CursorCheck
Screen_INT_0E_Finish:
			pop ax
			pop di
            ret

			; Translate common control codes
Screen_INT_0E_Control:
			cmp al, 7	; Bell
			jne Screen_INT_0E_Not07
			call IPC_ScreenOut
			jmp Screen_INT_0E_Finish
			ret
Screen_INT_0E_Not07:
			cmp al, 8	; BackSpace
			jne Screen_INT_0E_Not08
			mov ax, [Data_CursorVirtual]
			dec al
			test al, 80h
			jz Screen_INT_0E_BkSp
			xor al, al
			dec ah
			test ah, 80h
			jz Screen_INT_0E_BkSp
			xor ah, ah
Screen_INT_0E_BkSp:
            mov [Data_CursorVirtual], ax
			call Screen_CursorCalc
			mov di, [Data_CursorPhysical]
			mov [es:di], word 0020h
            jmp Screen_INT_0E_Finish
Screen_INT_0E_Not08:
			cmp al, 13	; CR
			jne Screen_INT_0E_Not0D
			mov byte [Data_CursorVirtual], 0
			call Screen_CursorCalc
			call Screen_Refresh
			jmp Screen_INT_0E_Finish
Screen_INT_0E_Not0D:
			cmp al, 10	; LF
			jne Screen_INT_0E_Not0A
			inc byte [Data_CursorVirtual+1]
			call Screen_CursorCheck
			call Screen_CursorCalc
			jmp Screen_INT_0E_Finish
Screen_INT_0E_Not0A:
			jmp Screen_INT_0E_Output
			
; -----------------------------------------------------------------
; INT 10 function 0F - get video mode.
; -----------------------------------------------------------------

Screen_INT_0F:
			; MDA text mode
			mov al, 07h		
			mov ah, 80
			mov bh, 0
			ret

; -----------------------------------------------------------------
; Load DS and ES with appropriate segment values.
; -----------------------------------------------------------------

Screen_Segments:
            mov ax, Data_Segment
            mov ds, ax
			mov ax, Screen_Segment
			mov es, ax
            ret
			
; -----------------------------------------------------------------
; Recalculate physical cursor position from virtual position.
; -----------------------------------------------------------------

Screen_CursorCalc:
            push cx
            push ax
            mov al, [Data_CursorVirtual+1]
            xor ah, ah
            mov cl, 80
            mul cl
            add al, [Data_CursorVirtual]
            adc ah, 0
            shl ax, 1
            mov [Data_CursorPhysical], ax
            pop ax
            pop cx
            ret

; -----------------------------------------------------------------
; Clear the entire screen.
; -----------------------------------------------------------------

Screen_Clear:
            push di
            push cx
            push ax
            xor ax, ax
   			mov di, ax
			mov al, 20h
			mov cx, 2000
			rep stosw
			pop ax
			pop cx
			pop di
			ret

; -----------------------------------------------------------------
; Check if the cursor has moved to the 26th line.
; If this is the case, scroll the screen up 1 line.
; -----------------------------------------------------------------

Screen_CursorCheck:
            cmp byte [Data_CursorVirtual+1], 25
            jb Screen_CursorCheck_End
            mov byte [Data_CursorVirtual+1], 24
            push ds
            push ax
            push cx
            push si
            push di
            mov cx, es
            mov ds, cx
            mov si, 160
            mov di, 0
            mov cx, 1920
            rep movsw
            mov ax, 0020h
            mov cx, 80
            rep stosw
            pop di
            pop si 
            pop cx
            pop ax
            pop ds
            call Screen_Refresh
Screen_CursorCheck_End:
            ret

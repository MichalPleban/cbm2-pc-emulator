

CHAR_CLRSCR	equ 147
CHAR_RVSON	equ 18
CHAR_RVSOFF	equ 146
CHAR_DEL	equ	20
CHAR_DOWN	equ	17

; -----------------------------------------------------------------
; Implements a jump table to select various interrupt routines.
; Input:
;			BP - offset to the function table
;			AH - function number
; -----------------------------------------------------------------

INT_Dispatch:
			push bx
			mov bl, ah
			xor bh, bh
			shl bx, 1
			add bp, bx
			pop bx
			call [cs:bp]
			ret

INT_Unimplemented:
			ret

; -----------------------------------------------------------------
; INT 10 - screen functions.
; -----------------------------------------------------------------

INT_10:
			cmp ah, 0Fh
			jg INT_10_Ret
			push bp
			push es
			mov bp, Data_Segment
			mov es, bp
			mov bp, INT_10_Functions
			call INT_Dispatch
			pop es
			pop bp
INT_10_Ret:
			iret

INT_10_Functions:
			dw INT_10_00
			dw INT_Unimplemented
			dw INT_10_02
			dw INT_10_03
			dw INT_Unimplemented
			dw INT_Unimplemented
			dw INT_10_06
			dw INT_10_07
			dw INT_Unimplemented
			dw INT_10_09
			dw INT_10_0A
			dw INT_Unimplemented
			dw INT_Unimplemented
			dw INT_Unimplemented
			dw INT_10_0E
			dw INT_10_0F
			
; -----------------------------------------------------------------
; INT 10 function 00 - set video mode.
; Outputs "clear screen" character.
; -----------------------------------------------------------------
			
INT_10_00:
			; Make whole screen editable
			call IPC_WindowRemove

			; Output "clear screen" character
			mov al, CHAR_CLRSCR
			call IPC_ScreenOut
			
			; Cancel editing mode
			mov al, 'O'
			call IPC_ScreenEscape
			
			; Cancel screen reverse
			mov al, 'N'
			call IPC_ScreenEscape
			
			; Reset the cursor position
			xor ax, ax
			mov [es:Data_CursorVirtual], ax
			mov [es:Data_CursorPhysical], ax
			
			ret

; -----------------------------------------------------------------
; INT 10 function 02 - set cursor position
; -----------------------------------------------------------------
			
INT_10_02:
			; MS BASIC Compiler runtime calls this function with DX=FFFF ?
			test dx, 8080h
			jnz INT_10_02_Ret

			; Check if row and column are within allowed bounds
			cmp dh, 24
			jl INT_10_02_RowOK
			mov dh, 23
INT_10_02_RowOK:
			cmp dl, 80
			jl INT_10_02_ColumnOK
			mov dl, 79
INT_10_02_ColumnOK:

			mov [es:Data_CursorVirtual], dx
			cmp dx, [es:Data_CursorPhysical]
			je INT_10_02_Ret
			
			mov [es:Data_CursorPhysical], dx
			call IPC_CursorSet

INT_10_02_Ret:
			ret

; -----------------------------------------------------------------
; INT 10 function 03 - get cursor position
; -----------------------------------------------------------------
			
INT_10_03:
			mov dx, [es:Data_CursorVirtual]
			mov cx, 0C0Dh
			ret

; -----------------------------------------------------------------
; INT 10 function 06 - scroll screen up
; INT 10 function 07 - scroll screen down
; -----------------------------------------------------------------

INT_10_06:
INT_10_07:
			push ax
			call IPC_WindowSet
			pop ax
			
			; 0 lines = clear screen
			test al, al
			jz INT_10_06_Clear
			
			; Scroll direction
			cmp ah, 06h
			jnz INT_10_06_Down
			mov al, 'V'
			jmp INT_10_06_Scroll
INT_10_06_Down:
			mov al, 'W'
INT_10_06_Scroll:
			call IPC_ScreenEscape
			jmp IPC_WindowRemove

INT_10_06_Clear:
			mov al, CHAR_CLRSCR
			call IPC_ScreenOut
			jmp IPC_WindowRemove

; -----------------------------------------------------------------
; INT 10 function 09 - write character and attribute.
; -----------------------------------------------------------------

INT_10_09:
			; MS BASIC Compiler runtime calls this function with AL=00 ?
			test al, al
			jz INT_10_09_Ret
			test cx, cx
			jz INT_10_09_Ret
			
			; Check if cursor position has not changed
			call INT_10_CursorCheck
			
			; Check if the attribute means "invert"
			push bx
			and bl, 77h
			xor bl, 07h
			cmp bl, 77h
			jne INT_10_09_NoReverse1
			push ax
			mov al, CHAR_RVSON
			call IPC_ScreenOut
			pop ax
INT_10_09_NoReverse1:
			
			; Output characters one by one
			push cx
			push ax
			call IPC_ScreenConvert
INT_10_09_Loop:
			call IPC_ScreenOut
			loop INT_10_09_Loop
			pop ax
			pop cx
			
			; Cancel invert
			cmp bl, 77h
			jne INT_10_09_NoReverse2
			push ax
			mov al, CHAR_RVSOFF
			call IPC_ScreenOut
			pop ax
INT_10_09_NoReverse2:
			pop bx	
			
			call INT_10_CursorAdvance
			
INT_10_09_Ret:
			ret

; -----------------------------------------------------------------
; INT 10 function 0A - write character only.
; -----------------------------------------------------------------

INT_10_0A:
			push bx
			xor bl, bl
			call INT_10_09
			pop bx
			ret

; -----------------------------------------------------------------
; Checks if virtual and physical cursor positions match.
; -----------------------------------------------------------------

INT_10_CursorCheck:
			push dx
			mov dx, [es:Data_CursorVirtual]
			cmp dx, [es:Data_CursorPhysical]
			je INT_10_CursorCheck_OK
			mov [es:Data_CursorPhysical], dx
			call IPC_CursorSet
INT_10_CursorCheck_OK:
			pop dx
			ret

; -----------------------------------------------------------------
; Moves the virtual cursor position.
; Input:
;			CX - number of characters to move
; -----------------------------------------------------------------

INT_10_CursorAdvance:
			push dx
			mov dl, [es:Data_CursorPhysical]
			xor dh, dh
			add dx, cx

INT_10_CursorAdvance_0:
			cmp dx, 80
			jl INT_10_CursorAdvance_Ret
			inc byte [es:Data_CursorPhysical+1]
			sub dx, 80
			jmp INT_10_CursorAdvance_0
			
INT_10_CursorAdvance_Ret:
			mov [es:Data_CursorPhysical], dl
			pop dx
			ret
			
; -----------------------------------------------------------------
; INT 10 function 0E - teletype output.
; -----------------------------------------------------------------

INT_10_0E:
			; Check if cursor position has not changed
			call INT_10_CursorCheck
			
			; Check control characters
			cmp al, 20h
			jl INT_10_0E_Control
			call IPC_ScreenConvert
INT_10_0E_Output:
			call IPC_ScreenOut
			
INT_10_0E_Finish:
			; Set new cursor position
			push dx
			call IPC_CursorGet
			mov [es:Data_CursorVirtual], dx
			mov [es:Data_CursorPhysical], dx
			pop dx

			ret

			; Translate common control codes
INT_10_0E_Control:
			cmp al, 7	; Bell
			jne INT_10_0E_Not07
			call IPC_ScreenOut
			ret
INT_10_0E_Not07:
			cmp al, 8	; BackSpace
			jne INT_10_0E_Not08
			mov al, CHAR_DEL
			jmp INT_10_0E_Output
INT_10_0E_Not08:
			cmp al, 10	; LF
			jne INT_10_0E_Not0A
			mov al, CHAR_DOWN
			jmp INT_10_0E_Output
INT_10_0E_Not0A:
			cmp al, 13	; CR
			jne INT_10_0E_Not0D
			mov al, 'J'
			call IPC_ScreenEscape
			jmp INT_10_0E_Finish
INT_10_0E_Not0D:
			ret
			
; -----------------------------------------------------------------
; INT 10 function 0F - get video mode.
; -----------------------------------------------------------------

INT_10_0F:
			; MDA text mode
			mov al, 07h		
			mov ah, 80
			mov bh, 0
			ret

; -----------------------------------------------------------------
; INT 11 - equipment list.
; -----------------------------------------------------------------

INT_11:
			; Return data: 2 disk drives, MDA card, 64K+ memory, 1 serial port
			mov ax, 037Dh
			iret

; -----------------------------------------------------------------
; INT 12 - memory size.
; -----------------------------------------------------------------

INT_12:
			; Return 256 kilobytes
			mov ax, 256
			iret


; -----------------------------------------------------------------
; INT 13 - disk functions.
; -----------------------------------------------------------------

INT_13:
			cmp ah, 1Bh
			jg INT_13_Ret
			push bp
			mov bp, INT_13_Functions
			call INT_Dispatch
			pop bp
			retf 2
INT_13_Ret:
			iret

INT_13_Functions:
			dw INT_13_OK
			dw INT_13_01
			dw INT_13_02
			dw INT_13_03
			dw INT_13_OK
			dw INT_13_Error
			dw INT_13_Error
			dw INT_13_Error
			dw INT_13_08
			dw INT_13_Error
			dw INT_13_Error
			dw INT_13_Error
			dw INT_13_Error
			dw INT_13_Error
			dw INT_13_Error
			dw INT_13_Error
			dw INT_13_Error
			dw INT_13_Error
			dw INT_13_Error
			dw INT_13_Error
			dw INT_13_Error
			dw INT_13_15
			dw INT_13_16
			dw INT_13_Error
			dw INT_13_Error
			dw INT_13_Error
			dw INT_13_Error

; -----------------------------------------------------------------
; INT 13 function 00 - reset drive.
; -----------------------------------------------------------------

INT_13_OK:
			clc
			ret
			
INT_13_Error:
			stc
			mov al, 02h
			ret

; -----------------------------------------------------------------
; INT 13 function 01 - get status.
; -----------------------------------------------------------------

INT_13_01:
			clc
			xor al, al
			ret
			
; -----------------------------------------------------------------
; INT 13 function 02 - disk read.
; Input:
;           CL - physical sector number
;           DH - physical head number
;           CH - physical track number
; -----------------------------------------------------------------

INT_13_02:
INT_13_03:
			push ax
			push es
			push cx
			push ax
			
			call INT_13_Logical	

			pop cx
			xor ch, ch
			shl cx, 1			
INT_13_02_Loop:
			push ax
			call IPC_SectorCalc
			mov bp, sp
			add bp, 7
			test [ss:bp], byte 01h
			jnz INT_13_02_Write
			call IPC_SectorRead
			jmp INT_13_02_Finish
INT_13_02_Write:
			call IPC_SectorWrite
INT_13_02_Finish:
			mov ax, es
			add ax, 16
			mov es, ax
			pop ax
			inc ax
			loop INT_13_02_Loop
			
			pop cx
			pop es
			pop ax
			ret
			
; -----------------------------------------------------------------
; INT 13 function 08 - get drive parameters.
; -----------------------------------------------------------------

INT_13_08:
			clc
			xor ah, ah
			mov bl, 03h
			mov ch, 80
			mov cl, 9
			mov dh, 1
			mov dl, 2
			; TODO: ES:DI pointer
			ret

; -----------------------------------------------------------------
; INT 13 function 15 - get disk change type.
; -----------------------------------------------------------------

INT_13_15:
			clc
			mov ah, 01h
			ret

; -----------------------------------------------------------------
; INT 13 function 16 - get disk change flag.
; -----------------------------------------------------------------

INT_13_16:
			clc
			mov ah, 01h
			ret

; -----------------------------------------------------------------
; Calculate logical sector number from PC geometry.
; Input:
;           CL - physical sector number
;           DH - physical head number
;           CH - physical track number
; Output:
;			AX - logical sector number
; -----------------------------------------------------------------

PC_HEADS    equ     2
PC_SECTORS  equ     9
            
INT_13_Logical:
			push bx
            mov al, ch
            xor ah, ah
            mov bl, PC_HEADS
            mul bl
            add al, dh
            mov bl, PC_SECTORS
            mul bl
            mov bl, cl
            dec bl
            xor bh, bh
            add ax, bx
            shl ax, 1
            pop bx
            ret
            
            
; -----------------------------------------------------------------
; INT 14 - serial functions.
; -----------------------------------------------------------------

INT_14:
			cmp ah, 03h
			jg INT_14_Ret
			push bp
			mov bp, INT_14_Functions
			call INT_Dispatch
			pop bp
INT_14_Ret:
			iret

INT_14_Functions:
			dw INT_14_00
			dw INT_14_01
			dw INT_14_02
			dw INT_14_03

; -----------------------------------------------------------------
; INT 14 function 00 - initialize serial port (unimplemented).
; -----------------------------------------------------------------
			
INT_14_00:
			ret

; -----------------------------------------------------------------
; INT 14 function 01 - send character.
; -----------------------------------------------------------------
			
INT_14_01:
			test dx, dx
			jnz INT_14_NoPort
			call IPC_SerialOut
			xor ah, ah
			ret
INT_14_NoPort:
			ret

; -----------------------------------------------------------------
; INT 14 function 02 - receive character.
; -----------------------------------------------------------------
			
INT_14_02:
			test dx, dx
			jnz INT_14_NoPort
			call IPC_SerialIn
			xor ah, ah
			ret

; -----------------------------------------------------------------
; INT 14 function 03 - get serial port status.
; -----------------------------------------------------------------
			
INT_14_03:
			test dx, dx
			jnz INT_14_NoPort
			mov ax, 6110h	
			ret

; -----------------------------------------------------------------
; INT 15 - BIOS functions.
; -----------------------------------------------------------------

INT_15:
			iret

; -----------------------------------------------------------------
; INT 16 - keyboard functions.
; -----------------------------------------------------------------

INT_16:
			cmp ah, 03h
			jg INT_16_Ret
			push bp
			mov bp, INT_16_Functions
			call INT_Dispatch
			pop bp
			retf 2 		; To retain the ZF flag!
INT_16_Ret:
			iret

INT_16_Functions:
			dw INT_16_00
			dw INT_16_01
			dw INT_16_02
			dw INT_Unimplemented

; -----------------------------------------------------------------
; INT 16 function 00 - read from keyboard buffer.
; -----------------------------------------------------------------

INT_16_00:
			call IPC_KbdPeek
			jz INT_16_00
			call IPC_KbdClear
			call IPC_KbdConvert
			ret

; -----------------------------------------------------------------
; INT 16 function 01 - peek into keyboard buffer.
; -----------------------------------------------------------------

INT_16_01:
			call IPC_KbdPeek
			jz INT_16_NoKey
			call IPC_KbdConvert
			ret
INT_16_NoKey:
			xor ax, ax
			ret

; -----------------------------------------------------------------
; INT 16 function 02 - get shift key state.
; -----------------------------------------------------------------

INT_16_02:
			call IPC_KbdPeek
			shr ah, 1
			shr ah, 1
			shr ah, 1
			shr ah, 1
			mov al, ah
			and ax, 0201h
			shl ah, 1
			or al, ah
			xor al, 05h
			ret

; -----------------------------------------------------------------
; INT 17 - printer functions.
; -----------------------------------------------------------------

INT_17:
			cmp ah, 02h
			jg INT_17_Ret
			push bp
			mov bp, INT_17_Functions
			call INT_Dispatch
			pop bp
INT_17_Ret:
			iret

INT_17_Functions:
			dw INT_17_00
			dw INT_17_01
			dw INT_17_02

; -----------------------------------------------------------------
; INT 17 function 00 - output byte to printer.
; -----------------------------------------------------------------
			
INT_17_00:
			call IPC_PrinterOut
			ret

; -----------------------------------------------------------------
; INT 17 function 01 - initialize printer (unimplemented).
; -----------------------------------------------------------------
			
INT_17_01:
			ret

; -----------------------------------------------------------------
; INT 17 function 02 - get printer status.
; -----------------------------------------------------------------
			
INT_17_02:
			mov ah, 80h
			ret

; -----------------------------------------------------------------
; INT 18 - ROM BASIC.
; -----------------------------------------------------------------

INT_18:
			iret

; -----------------------------------------------------------------
; INT 19 - Reboot.
; -----------------------------------------------------------------

INT_19:
			iret

; -----------------------------------------------------------------
; INT 1A - Timer functions.
; -----------------------------------------------------------------

INT_1A:
			iret
			
; -----------------------------------------------------------------
; INT 1B - Ctrl+Break.
; -----------------------------------------------------------------

INT_1B:
			iret
			
; -----------------------------------------------------------------
; INT 1C - System tick.
; -----------------------------------------------------------------

INT_1C:
			iret
			
; -----------------------------------------------------------------
; INT 1E - disk parameter table.
; -----------------------------------------------------------------

INT_1E:
			db 0DFh
			db 02h
			db 25h
			db 02h
			db 09h
			db 2Ah
			db 0FFh
			db 50h
			db 0F6h
			db 0Fh
			db 02h
			db 00h

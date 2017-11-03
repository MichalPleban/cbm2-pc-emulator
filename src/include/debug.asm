

%ifndef DEBUG

%macro		INT_Debug 1
%endmacro

%else

%macro		INT_Debug 1
			push ax
			push ds
			mov ax, Data_Segment
			mov ds, ax
			call IPC_KbdPeek
			jz %%1
			cmp al, 46h
			jnz %%1
			call IPC_KbdClear
			mov al, [Data_Debug]
			xor al, 01h
			mov [Data_Debug], al
%%1:
			test [Data_Debug], byte 1
			pop ds
			pop ax
			jz %%2
			push bp
			mov bp, %1
			call Debug_All
			pop bp
%%2:
%endmacro

%macro		Debug_Reg 2
			push ax
			push %2
			mov al, ','
			call Debug_Char
			mov al, ' '
			call Debug_Char
			mov ax, %1
			call Debug_Char
			mov al, ah
			call Debug_Char
			mov al, '='
			call Debug_Char
			pop ax
			call Debug_Word
			pop ax
%endmacro

; --------------------------------------------------------------------------------------
; Output registers to debug device.
; --------------------------------------------------------------------------------------

Debug_All:
			push ax
			push ax
			mov al, 'I'
			call Debug_Char
			mov al, 'N'
			call Debug_Char
			mov al, 'T'
			call Debug_Char
			mov al, ' '
			call Debug_Char
			mov ax, bp
			call Debug_Byte
			pop ax
			Debug_Reg "AX", ax
			Debug_Reg "BX", bx
			Debug_Reg "CX", cx
			Debug_Reg "DX", dx
			Debug_Reg "DS", ds
			Debug_Reg "ES", es
			Debug_Reg "SI", si
			Debug_Reg "DI", di
			mov al, 13
			call Debug_Char
			pop ax
			ret

; --------------------------------------------------------------------------------------
; Output hexadecimal word to debug device.
; Input:
;			AX - word
; --------------------------------------------------------------------------------------

Debug_Word:
			push ax
			mov al, ah
			call Debug_Byte
			pop ax
			call Debug_Byte
			ret

; --------------------------------------------------------------------------------------
; Output hexadecimal byte to debug device.
; Input:
;			AL - byte
; --------------------------------------------------------------------------------------

Debug_Byte:
			push ax
			pop ax
			push ax
			shr al, 1
			shr al, 1
			shr al, 1
			shr al, 1
			call Debug_Hex
			pop ax
			and al, 0Fh
			call Debug_Hex
			ret

; --------------------------------------------------------------------------------------
; Output hexadecimal digit to debug device.
; Input:
;			AL - digit (0-F)
; --------------------------------------------------------------------------------------

Debug_Hex:
			add al, 30h
			cmp al, 39h
			jbe Debug_Hex1
			add al, 7
Debug_Hex1:

; --------------------------------------------------------------------------------------
; Output ASCII character to debug device.
; Input:
;			AL - character code
; --------------------------------------------------------------------------------------

Debug_Char:
			call IPC_SerialOut
			ret
			
; --------------------------------------------------------------------------------------
; Processor single step routine.
; --------------------------------------------------------------------------------------

INT_01:
			push bp
			mov bp, sp
			push ax
			mov ax, [ss:bp+4]
			call Debug_Word 
			mov al, ':'
			call Debug_Char
			mov ax, [ss:bp+2]
			call Debug_Word 
;			mov al, 10
;			call Debug_Char
			mov al, 13
			call Debug_Char
			pop ax
			or word [ss:bp+6], 0100h
			pop bp
			iret

%endif


Virtual_Segment equ 0E000h

Virtual_Init:
            push es
            push cx
            push ax
            in al, 0E4h
            or al, 010h
            out 0E4h, al
            xor ax, ax
            mov di, ax
            mov ax, Virtual_Segment
            mov es, ax
            mov cx, 0400h
Virtual_Init1:
            mov ax, Virtual_In
            stosw
            mov ax, cs
            stosw
            loop Virtual_Init1
            mov cx, 0400h
Virtual_Init2:
            mov ax, Virtual_Out
            stosw
            mov ax, cs
            stosw
            loop Virtual_Init2
            pop ax
            pop cx
            pop es
            ret

Virtual_Handle:
            push ds
            push bp
            push dx
            push ax
            mov dx, Virtual_Segment
            mov ds, dx
            in al, 0E6h
            mov dh, al
            in al, 0E5h
            mov dl, al
            mov ax, dx            
            shl ax, 1
            shl ax, 1
            mov bp, ax
            pop ax
            and dx, 03FFh
            call far [ds:bp]
            pop dx
            pop bp
            pop ds
            iret

Virtual_Out:
            push ax
            mov al, 'O'
            call IPC_SerialOut
            mov al, 'U'
            call IPC_SerialOut
            mov al, 'T'
            call IPC_SerialOut
            mov al, ' '
            call IPC_SerialOut
            mov al, dh
            call Virtual_Hex
            mov al, dl
            call Virtual_Byte
            mov al, ','
            call IPC_SerialOut
            mov al, ' '
            call IPC_SerialOut
            pop ax
            push ax
            call Virtual_Byte
            mov al, 13
            call IPC_SerialOut
            pop ax
            retf

Virtual_In:
            push ax
            mov al, 'I'
            call IPC_SerialOut
            mov al, 'N'
            call IPC_SerialOut
            mov al, ' '
            call IPC_SerialOut
            mov al, ' '
            call IPC_SerialOut
            mov al, dh
            call Virtual_Hex
            mov al, dl
            call Virtual_Byte
            mov al, 13
            call IPC_SerialOut
            pop ax
            retf

; --------------------------------------------------------------------------------------
; Output hexadecimal byte to serial port.
; Input:
;			AL - byte
; --------------------------------------------------------------------------------------

Virtual_Byte:
			push ax
			pop ax
			push ax
			shr al, 1
			shr al, 1
			shr al, 1
			shr al, 1
			call Virtual_Hex
			pop ax
			call Virtual_Hex
			ret

; --------------------------------------------------------------------------------------
; Output hexadecimal digit to serial port.
; Input:
;			AL - digit (0-F)
; --------------------------------------------------------------------------------------

Virtual_Hex:
            and al, 0Fh
			add al, 30h
			cmp al, 39h
			jbe Virtual_Hex1
			add al, 7
Virtual_Hex1:
			call IPC_SerialOut
			ret

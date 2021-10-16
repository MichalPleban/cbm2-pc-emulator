
Virtual_Segment equ 0E000h

%macro		Virtual_IN 	2
            mov [es:(%1*4)], word %2
%endmacro

%macro		Virtual_OUT 	2
            mov [es:(1000h+%1*4)], word %2
%endmacro

; --------------------------------------------------------------------------------------
; Install virtual port handlers.
; --------------------------------------------------------------------------------------

Virtual_Init:
            push ds
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
            mov ds, ax
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
            
            call V_PIC_Init
            Virtual_IN  021h, V_IN_021
            Virtual_OUT 020h, V_OUT_020
            Virtual_OUT 021h, V_OUT_021

            call V_PIT_Init
            Virtual_OUT 043h, V_OUT_043

            call V_Speaker_Init
            Virtual_IN  061h, V_IN_061
            Virtual_OUT 061h, V_OUT_061
            Virtual_OUT 042h, V_OUT_042

            call V_Serial_Init
            Virtual_IN  3F8h, V_IN_3F8
            Virtual_IN  3F9h, V_IN_3F9
            Virtual_IN  3FAh, V_IN_3FA
            Virtual_IN  3FBh, V_IN_3FB
            Virtual_IN  3FCh, V_IN_3FC
            Virtual_IN  3FDh, V_IN_3FD
            Virtual_IN  3FEh, V_IN_3FE
            Virtual_OUT 3F8h, V_OUT_3F8
            Virtual_OUT 3F9h, V_OUT_3F9
            Virtual_OUT 3FBh, V_OUT_3FB
            Virtual_OUT 3FCh, V_OUT_3FC
            
            pop ax
            pop cx
            pop es
            pop ds
            ret

; --------------------------------------------------------------------------------------
; NMI handler routine - read port number and call appropriate handler.
; --------------------------------------------------------------------------------------

Virtual_Handle:
            push ds
            push bp
            push dx
            push ax
            in al, 0EBh
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
            and dx, 03FFh
            test ah, 10h
            jz Virtual_Handle_In
            pop ax
            call far [ds:bp]
            pop ax
            jmp Virtual_Handle_End
Virtual_Handle_In:
            pop ax
            pop ax
            call far [ds:bp]
            call Virtual_Stack
Virtual_Handle_End:
            pop dx
            pop bp
            pop ds
            iret

; --------------------------------------------------------------------------------------
; Default output routine - send port number and value to serial port.
; --------------------------------------------------------------------------------------

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

; --------------------------------------------------------------------------------------
; Default input routine - send port number to serial port.
; --------------------------------------------------------------------------------------

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
; Very ugly hack.
; --------------------------------------------------------------------------------------

Virtual_Stack:
            push ax
            mov bp, sp
            mov ax, [ss:bp+12]
            mov ds, ax
            mov ax, [ss:bp+10]
            mov bp, ax
            cmp [ds:bp-4], byte 0E4h
            je Virtual_Stack_Twobyte
            cmp [ds:bp-3], byte 0ECh
            jne Virtual_Stack_End
Virtual_Stack_Twobyte:
            mov al, [ds:bp-2]
            cmp al, 0A8h            ; TEST AL, xx
            je Virtual_Stack_Twobyte2
            cmp al, 0Ch             ; OR AL, xx
            je Virtual_Stack_Twobyte2
            cmp al, 24h             ; AND AL, xx
            je Virtual_Stack_Twobyte2
            cmp al, 3Ch             ; CMP AL, xx
            je Virtual_Stack_Twobyte2
            cmp al, 88h             ; MOV xx, AL
            je Virtual_Stack_Twobyte2
            jne Virtual_Stack_End
Virtual_Stack_Twobyte2:
            mov bp, sp
            mov ax, [ss:bp+10]
            dec ax
            dec ax
            mov [ss:bp+10], ax
Virtual_Stack_End:
            pop ax
            ret

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

%include "src/8088/virtual/pic.asm"
%include "src/8088/virtual/pit.asm"
%include "src/8088/virtual/speaker.asm"
%include "src/8088/virtual/serial.asm"

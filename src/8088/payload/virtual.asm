
Virtual_Segment equ 0E000h

%macro		Virtual_IN 	2
            mov [es:(%1*4)], word %2
%endmacro

%macro		Virtual_OUT 	2
            mov [es:(1000h+%1*4)], word %2
%endmacro

%include "src/8088/virtual/pic.asm"
%include "src/8088/virtual/pit.asm"
%include "src/8088/virtual/speaker.asm"
%include "src/8088/virtual/serial.asm"
%include "src/8088/virtual/mda.asm"
%include "src/8088/virtual/kbd.asm"


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
            Virtual_IN 042h, V_IN_042
            Virtual_IN  061h, V_IN_061
            Virtual_OUT 042h, V_OUT_042
            Virtual_OUT 061h, V_OUT_061

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

            call V_MDA_Init
            Virtual_IN  3B4h, V_IN_3B4
            Virtual_IN  3B5h, V_IN_3B5
            Virtual_IN  3BAh, V_IN_3BA
            Virtual_IN  3DAh, V_IN_3DA
            Virtual_OUT 3B4h, V_OUT_3B4
            Virtual_OUT 3B5h, V_OUT_3B5
            
            call V_KBD_Init
            Virtual_IN  060h, V_IN_060
            
Virtual_Init_End:
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
; Very ugly hack. Check if the instruction before the NMI needs to be restarted.
; --------------------------------------------------------------------------------------

Virtual_Stack:
            push ax
            push bx
            mov bp, sp
            mov ax, [ss:bp+14]
            mov ds, ax
            mov ax, [ss:bp+12]
            mov bp, ax
            cmp [ds:bp-4], byte 0E4h
            je Virtual_Stack_Twobyte
            cmp [ds:bp-3], byte 0ECh
            jne Virtual_Stack_End
Virtual_Stack_Twobyte:
            mov al, [ds:bp-2]
            mov bx, Opcode_TwoByte
            db 2Eh                      ; CS:
            xlat
            cmp al, 1
            je Virtual_Stack_Twobyte2
            jb Virtual_Stack_End
            add bh, al
            mov al, [ds:bp-1]
            db 2Eh                      ; CS:
            xlat
            test al, al
            jz Virtual_Stack_End
Virtual_Stack_Twobyte2:
            mov bp, sp
            mov ax, [ss:bp+12]
            dec ax
            dec ax
            mov [ss:bp+12], ax
            jmp Virtual_Stack_End
Virtual_Stack_End:
            pop bx
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

; --------------------------------------------------------------------------------------
; Tables of instruction opcodes that require restarting after NMI.
; --------------------------------------------------------------------------------------

Opcode_OneByte:
	;   x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 xA xB xC xD xE xF
	db   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0    ; 0x
	db   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0    ; 1x
	db   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0    ; 2x
	db   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0    ; 3x
	db   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0    ; 4x
	db   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0    ; 5x
	db   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0    ; 6x
	db   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0    ; 7x
	db   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0    ; 8x
	db   0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0    ; 9x: 98 = CBW
	db   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0    ; Ax
	db   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0    ; Bx
	db   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0    ; Cx
	db   0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0    ; Dx: D7 = XLATB
	db   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0    ; Ex
	db   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0    ; Fx

Opcode_TwoByte:
	;   x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 xA xB xC xD xE xF
	db   1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1, 0, 1, 0, 0, 0    ; 0x: 00 = ADD AL, reg; 04 = ADD AL, imm; 08 = OR AL, reg; 0A = OR AL, reg; 0C = OR AL, imm
	db   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0    ; 1x
	db   1, 0, 1, 0, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0    ; 2x: 20 = AND AL, reg; 22 = AND AL, reg; 24 = AND AL, imm; 26 = ES; 2E = CS
	db   1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 0, 0, 1, 0, 1, 0    ; 3x: 30 = XOR AL, reg; 32 = XOR AL, reg; 34 = XOR AL, imm; 38 = CMP AL, reg; 3C = CMP AL, imm; 36 = SS; 3E = DS
	db   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0    ; 4x
	db   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0    ; 5x
	db   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0    ; 6x
	db   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0    ; 7x
	db   0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0    ; 8x: 88 = MOV xx, AL; 84 = TEST AL, reg
	db   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0    ; 9x
	db   0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0    ; Ax: A8 = TEST AL, imm
	db   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0    ; Bx
	db   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0    ; Cx
	db   2, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0    ; Dx
	db   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0    ; Ex
	db   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 0    ; Fx

Opcode_ThreeByte:
	;   x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 xA xB xC xD xE xF
	db   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0    ; 0x
	db   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0    ; 1x
	db   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0    ; 2x
	db   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0    ; 3x
	db   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0    ; 4x
	db   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0    ; 5x
	db   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0    ; 6x
	db   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0    ; 7x
	db   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0    ; 8x
	db   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0    ; 9x
	db   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0    ; Ax
	db   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0    ; Bx
	db   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0    ; Cx
	db   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0    ; Dx
	db   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0    ; Ex
	db   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0    ; Fx

Opcode_TwoByte_D0_D2:
	;   x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 xA xB xC xD xE xF
	db   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0    ; 0x
	db   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0    ; 1x
	db   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0    ; 2x
	db   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0    ; 3x
	db   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0    ; 4x
	db   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0    ; 5x
	db   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0    ; 6x
	db   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0    ; 7x
	db   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0    ; 8x
	db   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0    ; 9x
	db   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0    ; Ax
	db   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0    ; Bx
	db   1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0    ; Cx: D0 C0 = ROL AL, 1; D0 C8 = ROR AL, 1; D2 C0 = ROL AL, CL; D2 C8 = ROL AL, 1
	db   1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0    ; Dx: D0 D0 = RCL AL, 1; D0 D8 = RCR AL, 1; D2 D0 = RCL AL, CL; D2 D8 = RCL AL, 1
	db   1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0    ; Ex: D0 E0 = SHL AL, 1; D0 E8 = SHR AL, 1; D2 E0 = SHL AL, CL; D2 E8 = SHL AL, 1
	db   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0    ; Fx

Opcode_TwoByte_FE:
	;   x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 xA xB xC xD xE xF
	db   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0    ; 0x
	db   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0    ; 1x
	db   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0    ; 2x
	db   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0    ; 3x
	db   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0    ; 4x
	db   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0    ; 5x
	db   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0    ; 6x
	db   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0    ; 7x
	db   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0    ; 8x
	db   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0    ; 9x
	db   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0    ; Ax
	db   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0    ; Bx
	db   1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0    ; Cx: FE C0 = INC AL; FE C8 = DEC AL
	db   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0    ; Dx
	db   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0    ; Ex
	db   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0    ; Fx

			

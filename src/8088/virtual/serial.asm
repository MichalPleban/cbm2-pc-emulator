

V_Port_3F9      equ 02010h
V_Port_3FB      equ 02011h
V_Port_3FC      equ 02012h
V_Divisor_LSB   equ 02013h
V_Divisor_MSB   equ 02014h
V_Port_3F8      equ 02015h
V_Serial_Sent   equ 02016h
V_Serial_Received equ 02017h


V_Serial_Init:
            mov [V_Port_3F9], byte 00h
            mov [V_Port_3FB], byte 03h
            mov [V_Port_3FC], byte 03h
            mov [V_Serial_Sent], byte 00h
            mov [V_Serial_Received], byte 00h
            ret

V_Serial_Do:
            mov ax, [V_Divisor_LSB]
            mov bp, IPC_Serial_Divisor
            mov dl, 15
V_Serial_Do1:
            cmp ax, [cs:bp]
            jbe V_Serial_Do2
            add bp, 2
            dec dl
            jnz V_Serial_Do1
V_Serial_Do2:            
            mov al, [V_Port_3FB]
            and al, 1Fh
            call IPC_SerialConvert
            and al, 0F0h
            or al, dl
            call IPC_SerialParams
            ret
            
V_IN_3F8:
%ifdef SERIAL_DEBUG
            call Debug_In
%endif
            test [V_Port_3FB], byte 80h
            jnz V_IN_3F8_DLAB
            push ax
            call IPC_SerialStatus
            cmp al, 00h
            jne V_IN_3F8_Read
            pop ax
            mov al, 00h
            retf
V_IN_3F8_Read:
            call IPC_SerialIn
            mov [V_Port_3F8], al
            pop ax
            mov al, [V_Port_3F8]
            mov [V_Serial_Received], byte 00h
            retf
V_IN_3F8_DLAB:
            mov al, [V_Divisor_LSB]
            retf

V_IN_3F9:
%ifdef SERIAL_DEBUG
            call Debug_In
%endif
            test [V_Port_3FB], byte 80h
            jnz V_IN_3F9_DLAB
            mov al, [V_Port_3F9]
            retf
V_IN_3F9_DLAB:
            mov al, [V_Divisor_MSB]
            retf
            
V_IN_3FA:
%ifdef SERIAL_DEBUG
            call Debug_In
%endif
;            call IPC_SerialStatus
;            cmp al, 00h
;            je V_IN_3FA_Empty
            cmp [V_Serial_Received], byte 00h
            je V_IN_3FA_Empty
            mov al, 04h
            retf
V_IN_3FA_Empty:
            cmp [V_Serial_Sent], byte 80h
            jnz V_IN_3FA_None
            mov [V_Serial_Sent], byte 00h
            mov al, 02h
            retf
V_IN_3FA_None:
            mov al, 01h
            retf

V_IN_3FB:
%ifdef SERIAL_DEBUG
            call Debug_In
%endif
            mov al, [V_Port_3FB]
            retf

V_IN_3FC:
%ifdef SERIAL_DEBUG
            call Debug_In
%endif
            mov al, [V_Port_3FC]
            retf

V_IN_3FD:
%ifdef SERIAL_DEBUG
            call Debug_In
%endif
            call IPC_SerialStatus
            cmp al, 00h
            je V_IN_3FD_Empty
            mov al, 01h
V_IN_3FD_Empty:
            or al, 60h
            retf

V_IN_3FE:
%ifdef SERIAL_DEBUG
            call Debug_In
%endif
            mov al, 0B0h
            retf

V_OUT_3F8:
%ifdef SERIAL_DEBUG
            call Debug_Out
%endif
            test [V_Port_3FB], byte 80h
            jnz V_OUT_3F8_DLAB
            push ax
            call IPC_SerialOut
            ; Fake interrupt on finished data transmission
            mov [V_Serial_Sent], byte 80h
            int 0Ch
            pop ax
            retf
V_OUT_3F8_DLAB:
            mov [V_Divisor_LSB], al
            call V_Serial_Do
            retf

V_OUT_3F9:
%ifdef SERIAL_DEBUG
            call Debug_Out
%endif
            test [V_Port_3FB], byte 80h
            jnz V_OUT_3F9_DLAB
            mov [V_Port_3F9], al
            retf
V_OUT_3F9_DLAB:
            mov [V_Divisor_MSB], al
            call V_Serial_Do
            retf

V_OUT_3FB:
%ifdef SERIAL_DEBUG
            call Debug_Out
%endif
            mov [V_Port_3FB], al
            call V_Serial_Do
            retf

V_OUT_3FC:
%ifdef SERIAL_DEBUG
            call Debug_Out
%endif
            mov [V_Port_3FC], al
            retf
            

%ifdef SERIAL_DEBUG
            
Debug_In:
            ret
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
            ret

Debug_Out:
            ret
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
            ret

%endif

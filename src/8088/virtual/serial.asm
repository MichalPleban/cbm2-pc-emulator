

V_Port_3F9      equ 02010h
V_Port_3FB      equ 02011h
V_Port_3FC      equ 02012h
V_Divisor_LSB   equ 02013h
V_Divisor_MSB   equ 02014h
V_Port_3F8      equ 02015h


V_Serial_Init:
            mov [V_Port_3F9], byte 00h
            mov [V_Port_3FB], byte 03h
            mov [V_Port_3FC], byte 00h
            ret


V_IN_3F8:
;            call Debug_In
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
            retf
V_IN_3F8_DLAB:
            mov al, [V_Divisor_LSB]
            retf

V_IN_3F9:
;            call Debug_In
            test [V_Port_3FB], byte 80h
            jnz V_IN_3F9_DLAB
            mov al, [V_Port_3F9]
            retf
V_IN_3F9_DLAB:
            mov al, [V_Divisor_MSB]
            retf
            
V_IN_3FA:
;            call Debug_In
            call IPC_SerialStatus
            cmp al, 00h
            je V_IN_3FA_Empty
            mov al, 04h
            retf
V_IN_3FA_Empty:
            mov al, 01h
            retf

V_IN_3FB:
;            call Debug_In
            mov al, [V_Port_3FB]
            retf

V_IN_3FC:
;            call Debug_In
            mov al, [V_Port_3FC]
            retf

V_IN_3FD:
;            call Debug_In
            mov al, 60h
            retf

V_IN_3FE:
;            call Debug_In
            mov al, 0B0h
            retf

V_OUT_3F8:
;            call Debug_Out
            test [V_Port_3FB], byte 80h
            jnz V_OUT_3F8_DLAB
            push ax
            call IPC_SerialOut
            pop ax
            retf
V_OUT_3F8_DLAB:
            mov [V_Divisor_LSB], al
            retf

V_OUT_3F9:
;            call Debug_Out
            test [V_Port_3FB], byte 80h
            jnz V_OUT_3F9_DLAB
            mov [V_Port_3F9], al
            retf
V_OUT_3F9_DLAB:
            mov [V_Divisor_MSB], al
            retf

V_OUT_3FB:
;            call Debug_Out
            mov [V_Port_3FB], al
            retf

V_OUT_3FC:
;            call Debug_Out
            mov [V_Port_3FC], al
            retf
            
            
Debug_In:
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

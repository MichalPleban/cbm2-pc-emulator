

V_MDA_Data      equ 02030h     ; Buffer length 18 bytes
V_Port_03BA     equ 02042h
V_Port_03B4     equ 02043h
V_Port_03DA     equ 02044h

V_MDA_Init:
            mov [V_Port_03BA], byte 0
            mov [V_Port_03B4], byte 0
            mov [V_Port_03DA], byte 9
            ret

V_IN_3B4:
            mov al, [V_Port_03B4]
            retf

V_OUT_3B4:
            mov [V_Port_03B4], al
            retf

V_IN_3B5:
            push bx
            mov bx, V_MDA_Data
            mov al, [V_Port_03B4]
            cbw
            add bx, ax
            mov al, [bx]
            pop bx
            retf

V_OUT_3B5:
            push bx
            push ax
            mov bx, V_MDA_Data
            mov al, [V_Port_03B4]
            cbw
            add bx, ax
            pop ax
            mov [bx], al
            pop bx
            retf
            
V_OUT_3B8:
            shl al, 1
            shl al, 1
            shl al, 1
            or al, 7Fh
            call IPC_Video_SetOptions
            retf
            
V_IN_3BA:
            mov al, [V_Port_03BA]
            xor al, 80h
            mov [V_Port_03BA], al
            xor al, 80h
            retf

V_IN_3DA:
            mov al, [V_Port_03DA]
            xor al, 08h
            mov [V_Port_03DA], al
            xor al, 08h
            retf

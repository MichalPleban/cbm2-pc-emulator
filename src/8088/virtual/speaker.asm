

; Speaker status (corresponding to port 61)
V_Port_61       equ 02000h
V_Port_42_Write equ 02001h
V_Port_42_Sel   equ 02003h
V_Port_42_Read  equ 02004h
        
; Initialize port values
V_Speaker_Init:
        mov [V_Port_61], byte 00h
        mov [V_Port_42_Write], word 0000h
        mov [V_Port_42_Read], word 0000h
        mov [V_Port_42_Sel], byte 00h
        ret
        
; IN port 61 - return status
V_IN_061:
        mov al, [V_Port_61]
        retf

; OUT port 61 - update status
V_OUT_061:
        mov [V_Port_61], al
        call V_Speaker_Do
        retf

; IN port 42 - read frequency & fake decrement
V_IN_042:
        test [V_Port_42_Sel], byte 01h
        jnz V_IN_042_MSB
        mov al, [V_Port_42_Read]
        dec al
        mov [V_Port_42_Read], al
        mov al, [V_Port_42_Read+1]
        sbb al, 0
        mov [V_Port_42_Read+1], al
        mov al, [V_Port_42_Read]
        mov [V_Port_42_Sel], byte 01h
        jmp V_IN_042_End
V_IN_042_MSB:
        mov al, [V_Port_42_Read+1]
        mov [V_Port_42_Sel], byte 00h
V_IN_042_End:
        retf

; OUT port 42 - update frequency
V_OUT_042:
        test [V_Port_42_Sel], byte 01h
        jnz V_OUT_042_MSB
        mov [V_Port_42_Write], al
        mov [V_Port_42_Sel], byte 01h
        jmp V_OUT_042_End
V_OUT_042_MSB:
        mov [V_Port_42_Write+1], al
        mov [V_Port_42_Sel], byte 00h
        call V_Speaker_Do
V_OUT_042_End:
        retf
        
V_Speaker_Do:
        mov ax, [V_Port_42_Write]
        cmp ax, 99h
        jb V_Speaker_Silent
        push cx
        mov cx, ax
        mov dx, 0098h
        mov ax, 0BA15h
        div cx
        pop cx
        mov dl, [V_Port_61]
        and dl, 03h
        cmp dl, 03h
        jz V_Speaker_Do_1
V_Speaker_Silent:
        xor dl, dl
V_Speaker_Do_1:
        call IPC_Sound
V_Speaker_Do_End:
        ret

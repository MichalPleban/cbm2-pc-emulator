

V_Port_21       equ 02020h

V_PIC_Init:
            mov [V_Port_21], byte 0BCh
            ret

V_IN_021:
            mov al, [V_Port_21]
            retf

V_OUT_020:
            retf

V_OUT_021:
            mov [V_Port_21], al
            retf

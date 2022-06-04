
V_Port_60   equ 02050h ; The byte to be input at port 60


V_KBD_Init:
            mov [V_Port_60], byte 00h
            ret

V_IN_060:
            mov al, [V_Port_60]
            retf


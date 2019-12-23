
Hardware_Init:

            ; Check if external memory is present
            mov al, 1
            xor ah, ah
            mov bx, 0A000h
Hardware_Init1:
            mov es, ax
            mov cx, [0000h]
            mov [0000h], word 0A55Ah
            cmp [0000h], word 0A55Ah
            pushf
            mov [0000h], cx
            popf
            jnz Hardware_Init2
            or ah, al
Hardware_Init2:
            add bx, 0100h
            shl al, 1
            cmp al, 020h
            jne Hardware_Init1
            in al, 0E4h
            or al, ah
            out 0E4h, al
            ret



Hardware_Check:
            push cs
            pop ds

            ; Test the chipset version
            in al, 0EFh
            test al, 0F0h               ; No chipset = read back EF
            jz Hardware_Check1
            mov si, Hardware_Banner2
            call Output_String
            hlt
Hardware_Check1:
            mov si, Hardware_Banner1
            call Output_String
            in al, 0EFh
            and al, 0Fh
            add al, 30h
            int 10h
            mov al, 10
            int 10h
            mov al, 13
            int 10h

            ; Check if the RTC chip is present
            call I2C_Start
            mov al, 0D0h
            call I2C_Send
            pushf
            call I2C_Stop
            popf
            jnc Hardware_Check2
            mov si, Hardware_Banner3
            call Output_String
            hlt
Hardware_Check2:

            ; Check if the EEPROM chip is present
            call I2C_Start
            mov al, 0A0h
            call I2C_Send
            pushf
            call I2C_Stop
            popf
            jnc Hardware_Check3
            mov si, Hardware_Banner4
            call Output_String
            hlt
Hardware_Check3:

            ret
                        
Hardware_Banner1:
            db "Cobalt chipset revision ", 0
Hardware_Banner2:
            db "ERROR: Unsupported hardware.", 10, 13, 0
Hardware_Banner3:
            db "ERROR: RTC chip not present.", 10, 13, 0
Hardware_Banner4:
            db "ERROR: EEPROM chip not present.", 10, 13, 0

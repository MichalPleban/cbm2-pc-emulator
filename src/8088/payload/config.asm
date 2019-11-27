

; -----------------------------------------------------------------
; Zero the CMOS configuration
; -----------------------------------------------------------------

Config_Zero:
            call Config_Segment
            mov al, 010h
            stosb
            mov cx, 54
            xor al, al
            rep stosb
            mov al, 0B0h
            stosb
            ret

; -----------------------------------------------------------------
; Calculate the CMOS configuration checksum
; -----------------------------------------------------------------

Config_CRC:
            call Config_Segment
            mov ah, 0FFh

            mov cx, 55
Config_CRC1:
            lodsb
            mov bh, 8
Config_CRC2:
            mov bl, al
            xor bl, ah
            shr ah, 1
            test bl, 1
            jz Config_CRC3
            xor ah, 8Ch
Config_CRC3:
            shr al, 1
            dec bh
            jnz Config_CRC2
            loop Config_CRC1

            lodsb
            cmp ah, al
            ret

; -----------------------------------------------------------------
; Read the CMOS configuration into 9FF0:0090
; -----------------------------------------------------------------

Config_Read:
            call Config_Segment

            call I2C_Start
            
            mov al, 0D0h
            call I2C_Send
            
            mov al, 08h
            call I2C_Send
            
            call I2C_Start
            
            mov al, 0D1h
            call I2C_Send
            
            mov cx, 55
Config_Read1:
            clc
            call I2C_Receive
            stosb
            loop Config_Read1

            stc
            call I2C_Receive
            stosb
            
            call I2C_Stop
            
            ret

; -----------------------------------------------------------------
; Save the CMOS configuration from 9FF0:0090
; -----------------------------------------------------------------

Config_Write:
            call Config_Segment

            call I2C_Start
            
            mov al, 0D0h
            call I2C_Send
            
            mov al, 08h
            call I2C_Send
            
            mov cx, 56
Config_Write1:
            lodsb
            clc
            call I2C_Send
            loop Config_Write1
            
            call I2C_Stop
            
            ret

; -----------------------------------------------------------------
; Initialize registers for configuration reading
; -----------------------------------------------------------------

Config_Segment:
            mov ax, 9FF0h
            mov ds, ax
            mov es, ax
            mov ax, 0090h
            mov si, ax
            mov di, ax
            ret

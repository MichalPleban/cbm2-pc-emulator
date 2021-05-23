

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
            mov bx, MemTop - 10h
            mov ds, bx
            mov es, bx
            mov bx, 0090h
            mov si, bx
            mov di, bx
            ret

; -----------------------------------------------------------------
; Reset the CMOS configuration
; -----------------------------------------------------------------

Config_Reset:
            call Config_Zero
            call Config_Write
            call INT_19_Segments
            mov si, Config_Banner1
            call Output_String
            hlt

Config_Banner1:
			db "CMOS configuration has been reset. Please reset your machine.", 10, 13, 0

; -----------------------------------------------------------------
; Modify the CMOS configuration
; -----------------------------------------------------------------

Config_Modify:
            call Config_Read
            mov dl, [0090h]
            call INT_19_Segments
            call Output_Line
            mov si, Config_Banner2
            call Output_String
            mov si, Config_Banner_V0
            mov bl, 0
            call Config_Driver
            mov si, Config_Banner_V1
            mov bl, 1
            call Config_Driver
            mov si, Config_Banner_V2
            mov bl, 2
            call Config_Driver
            mov si, Config_Banner5
            call Output_String
Config_Modify1:
            call INT_16_00
            cmp al, 1Bh
            jz INT_19
            cmp al, 31h
            jb Config_Modify1
            cmp al, 33h
            ja Config_Modify1
            call Config_Segment
            sub al, 21h
            mov [0090h], al
            add al, 10h
            mov [0091h], al
            call Config_CRC
            mov [00C7h], ah
            call Config_Write
            call INT_19_Segments
            mov si, Config_Banner6
            call Output_String
            hlt
            
            
Config_Driver:
			mov ah, 0Eh
            add bl, 10h
            cmp bl, dl
            jnz Config_Driver1
            mov al, '['
			int 10h
            mov al, bl
            add al, 21h
			int 10h
            mov al, ']'
			int 10h
            jmp Config_Driver2
Config_Driver1:
            mov al, ' '
			int 10h
            mov al, bl
            add al, 21h
			int 10h
            mov al, ' '
			int 10h
Config_Driver2:
            mov al, ' '
			int 10h
            mov al, '-'
			int 10h
            mov al, ' '
			int 10h
            jmp Output_String
            
Config_Banner2:
			db "Select video driver:", 10, 13, 0
Config_Banner_V0:
			db "Inbuilt video (standard char ROM)", 10, 13, 0
Config_Banner_V1:
			db "Inbuilt video (PC char ROM)", 10, 13, 0
Config_Banner_V2:
			db "Michau's VGA interface", 10, 13, 0
Config_Banner5:
			db "Esc - Return to main menu", 10, 13, 0
Config_Banner6:
			db "New configuration has been saved. Please reset your machine.", 10, 13, 0

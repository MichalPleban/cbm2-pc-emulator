

org 0100h
            push cs
            pop ds
            mov dx, Msg_Prompt
            mov ah, 09h
            int 21h
            
            mov ah, 01h
            int 21h
            cmp al, 'Y'
            je Program
            cmp al, 'y'
            jne Exit
            
Program:
            mov dl, 10
            mov ah, 02h
            int 21h
            mov dl, 13
            mov ah, 02h
            int 21h

            call EEPROM_Setup
            call EEPROM_Program
                        
Exit:
            mov ax, 4C00h
            int 21h

EEPROM_Setup:

            mov ax, cs
            mov dx, Payload
            mov cl, 4
            shr dx, cl
            add ax, dx

            mov ds, ax
            xor ax, ax
            mov si, ax
            mov bx, [ds:0008h]
            ret

EEPROM_Program:

            cli
            cmp si, bx
            jbe EEPROM_Program1
            call I2C_Start
            mov al, 0A0h
            call I2C_Send
            xor al, al
            call I2C_Send
            xor al, al
            call I2C_Send
            mov al, 0EAh
            call I2C_Send
            call I2C_Stop
            call EEPROM_Wait
            sti
            ret
EEPROM_Program1:
            mov cx, 128
            call I2C_Start
            mov al, 0A0h
            call I2C_Send
            mov ax, si
            mov al, ah
            call I2C_Send
            mov ax, si
            call I2C_Send
EEPROM_Program2:
            lodsb
            cmp si, 1
            jne EEPROM_Program3
            mov al, 0FFh
EEPROM_Program3:
            call I2C_Send
            loop EEPROM_Program2
            call I2C_Stop
            call EEPROM_Wait
            mov dl, '.'
            mov ah, 02h
            int 21h
            jmp EEPROM_Program

EEPROM_Wait:
            call I2C_Start
            mov al, 0A0h
            call I2C_Send
            pushf
            call I2C_Stop
            popf
            jc EEPROM_Wait
            ret
            
            %include "src/8088/build.inc"
            %include "src/8088/payload/i2c.asm"

Msg_Prompt:
            db "This program will upgrade your ROM to build ", SOFTWARE_VERSION, SOFTWARE_BUILDS, 10, 13
            db "Do you want to continue? [Y/N] $"

            align 16, db 0
            
Payload:
            incbin 'dist/rom/payload.bin'

            
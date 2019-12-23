

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
            xor ah, ah
            int 0C0h
            mov ah, 02h
            mov al, 0A0h
            int 0C0h
            mov ah, 02h
            xor al, al
            int 0C0h
            mov ah, 02h
            xor al, al
            int 0C0h
            mov al, 0EAh
            mov ah, 02h
            int 0C0h
            mov ah, 01h
            int 0C0h
            call EEPROM_Wait
            sti
            ret
EEPROM_Program1:
            mov cx, 128
            xor ah, ah
            int 0C0h
            mov ah, 02h
            mov al, 0A0h
            int 0C0h
            mov ax, si
            mov al, ah
            mov ah, 02h
            int 0C0h
            mov ax, si
            mov ah, 02h
            int 0C0h
EEPROM_Program2:
            lodsb
            cmp si, 1
            jne EEPROM_Program3
            mov al, 0FFh
EEPROM_Program3:
            mov ah, 02h
            int 0C0h
            loop EEPROM_Program2
            mov ah, 01h
            int 0C0h
            call EEPROM_Wait
            mov dl, '.'
            mov ah, 02h
            int 21h
            jmp EEPROM_Program

EEPROM_Wait:
            xor ah, ah
            int 0C0h
            mov ah, 02h
            mov al, 0A0h
            int 0C0h
            pushf
            mov ah, 01h
            int 0C0h
            popf
            jc EEPROM_Wait
            ret
            
            %include "src/8088/build.inc"

Msg_Prompt:
            db "This program will upgrade your ROM to build ", SOFTWARE_VERSION, SOFTWARE_BUILDS, 10, 13
            db "Do you want to continue? [Y/N] $"

            align 16, db 0
            
Payload:
            incbin 'dist/rom/payload.bin'

            
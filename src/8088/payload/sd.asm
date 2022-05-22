
%define SD_HEADS 255
%define SD_SECTORS 63
%define SD_CYLINDERS 1024


%macro	SEL_HI 0
            mov al, 2*7+1       ; Set bit PC7 to 1
            out 23h, al
%endmacro

%macro	SEL_LO 0
            mov al, 2*7+0       ; Set bit PC7 to 0
            out 23h, al
%endmacro

%macro  SEND_BYTE 1
            mov al, %1
            out 0E0h, al
%endmacro

%macro  READ_BYTE 0
            SEND_BYTE 0FFh
            nop
            nop
            in al, 0E0h
%endmacro

; --------------------------------------------------------------------------------------
; Handle INT 13 interrupt for SD card.
; --------------------------------------------------------------------------------------

SD_Handle:
            cmp ah, 02h
            jz SD_Func_02
            cmp ah, 03h
            jz SD_Func_03
            cmp ah, 08h
            jz SD_Func_08
            cmp ah, 15h
            jz SD_Func_15
            cmp ah, 05h
            jz SD_Dummy
            cmp ah, 06h
            jz SD_Dummy
            cmp ah, 07h
            jz SD_Dummy
SD_Error:
			stc
			mov ah, 0FFh
			ret
			
; --------------------------------------------------------------------------------------
; Dummy functions
; --------------------------------------------------------------------------------------

SD_Dummy:
            clc
            xor ah, ah
            ret

; --------------------------------------------------------------------------------------
; Function 08 - return hard disk parameters.
; --------------------------------------------------------------------------------------

SD_Func_08:
            push cs
            pop es
            mov cx, SD_DBT
            mov di, cx
            mov dh, SD_HEADS-1
            mov dl, 1
            mov cl, SD_SECTORS + (((SD_CYLINDERS-1)>>8)<<6)
            mov ch, (SD_CYLINDERS-1)&255
            xor ah, ah
            mov bl, 11h
            clc
            ret
            
; --------------------------------------------------------------------------------------
; Function 15 - read disk type.
; --------------------------------------------------------------------------------------

SD_Func_15:
            mov ah, 3
            mov cx, (SD_SECTORS*SD_HEADS*SD_CYLINDERS)>>16
            mov dx, (SD_SECTORS*SD_HEADS*SD_CYLINDERS)&65535
            clc
            ret

; --------------------------------------------------------------------------------------
; Function 02 - read disk sector.
; --------------------------------------------------------------------------------------

SD_Func_02:
            call SD_Check
            jc SD_Error
            push dx
            push cx
            push di
            mov di, bx
            push bx
            mov bl, al
            push ax
            call SD_CHS
SD_Func_02_Loop:
            call SD_Read
            jc SD_Func_02_Error
            add ax, 1
            adc dl, 0
            dec bl
            jnz SD_Func_02_Loop
            pop ax
            pop bx
            pop di
            pop cx
            pop dx
            xor ah, ah
            clc
            ret
SD_Func_02_Error:
            pop ax
            pop bx
            pop di
            pop cx
            pop dx
            xor ax, ax
            dec ah
            stc
            ret
            
; --------------------------------------------------------------------------------------
; Function 03 - write disk sector.
; --------------------------------------------------------------------------------------

SD_Func_03:
            call SD_Check
            jc SD_Error
            push dx
            push cx
            push si
            mov si, bx
            push bx
            mov bl, al
            push ax
            call SD_CHS
            push ds
            push es
            pop ds
SD_Func_03_Loop:
            call SD_Write
            jc SD_Func_03_Error
            add ax, 1
            adc dl, 0
            dec bl
            jnz SD_Func_03_Loop
            pop ds
            pop ax
            pop bx
            pop si
            pop cx
            pop dx
            xor ah, ah
            clc
            ret
SD_Func_03_Error:
            pop ds
            pop ax
            pop bx
            pop di
            pop cx
            pop dx
            xor ax, ax
            dec ah
            stc
            ret
; -----------------------------------------------------------------
; Check if a SD card is present and has been properly initialized.
; -----------------------------------------------------------------

SD_Check:
            push ax
			push ds
			mov ax, Data_Segment
			mov ds, ax
            test byte [Data_SD], 80h
            jnz SD_Check_OK
            call SD_Init
            jnc SD_Check_Initialized
            pop ds
            pop ax
            stc
            ret
SD_Check_Initialized:
            mov al, byte [Data_SD]
            or al, 80h
            mov byte [Data_SD], al
SD_Check_OK:
            pop ds
            pop ax
            clc
            ret

; -----------------------------------------------------------------
; Initialize the SD card.
; -----------------------------------------------------------------

SD_Init:
            push cx
            push dx
            push ax
            push bx
            out 0E8h, al
            
            ; Step 1 - send dummy pulses with card deselected
            stc
            SEL_HI
            mov cx, 100
SD_Init_Loop_1:
            SEND_BYTE 0FFh
            loop SD_Init_Loop_1
            SEL_LO
            
            ; Step 2 - send dummy pulses with card selected
            mov cx, 5000
SD_Init_Loop_2:
            SEND_BYTE 0FFh
            loop SD_Init_Loop_2
            
            ; Step 3 - send CMD0
            SEND_BYTE 40h
            SEND_BYTE 00h
            SEND_BYTE 00h
            SEND_BYTE 00h
            SEND_BYTE 00h
            SEND_BYTE 95h
            READ_BYTE
            READ_BYTE
            mov bh, al
            READ_BYTE
            cmp bh, 01h
            jne SD_Init_Error

            ; Step 4 - send CMD8
            SEND_BYTE 48h
            SEND_BYTE 00h
            SEND_BYTE 00h
            SEND_BYTE 01h
            SEND_BYTE 0AAh
            SEND_BYTE 87h
            READ_BYTE
            READ_BYTE
            cmp al, 05h
            je SD_Init_Skip
            cmp al, 01h
            jne SD_Init_Error
            READ_BYTE
            READ_BYTE
            READ_BYTE
            READ_BYTE
SD_Init_Skip:
            READ_BYTE

            mov cx, 50000
SD_Init_New:
            ; Step 5a - send CMD55
            SEND_BYTE 77h
            SEND_BYTE 00h
            SEND_BYTE 00h
            SEND_BYTE 00h
            SEND_BYTE 00h
            SEND_BYTE 01h
            READ_BYTE
            READ_BYTE
            mov bh, al
            READ_BYTE
            cmp bh, 05h
            je SD_Init_Old
            cmp bh, 01h
            jne SD_Init_Error

            ; Step 5a - send ACMD41
            SEND_BYTE 69h
            SEND_BYTE 40h
            SEND_BYTE 00h
            SEND_BYTE 00h
            SEND_BYTE 00h
            SEND_BYTE 77h
            READ_BYTE
            READ_BYTE
            mov bh, al
            READ_BYTE
            cmp bh, 00h
            je SD_Init_Done
            cmp bh, 05h
            je SD_Init_Old
            cmp bh, 01h
            jne SD_Init_Error
            loop SD_Init_New2
            jmp SD_Init_Error
SD_Init_New2:
            jmp SD_Init_New

SD_Init_Old:
            ; Step 5a - send CMD41
            SEND_BYTE 41h
            SEND_BYTE 00h
            SEND_BYTE 00h
            SEND_BYTE 00h
            SEND_BYTE 00h
            SEND_BYTE 0F9h
            READ_BYTE
            READ_BYTE
            mov bh, al
            READ_BYTE
            cmp bh, 00h
            je SD_Init_Done
            cmp bh, 01h
            jne SD_Init_Error
            loop SD_Init_Old
            jmp SD_Init_Error
            
SD_Init_Done:
            ; Step 7 - send CMD58
            SEND_BYTE 7Ah
            SEND_BYTE 00h
            SEND_BYTE 00h
            SEND_BYTE 00h
            SEND_BYTE 00h
            SEND_BYTE 01h
            READ_BYTE
            READ_BYTE
            cmp al, 00h
            jne SD_Init_Error
            READ_BYTE
            mov bh, al
            READ_BYTE
            READ_BYTE
            READ_BYTE
            READ_BYTE
            test bh, 80h
            jnz SD_Init_Finished

SD_Init_Sector:
            ; Step 8 - send CMD16
            SEND_BYTE 50h
            SEND_BYTE 00h
            SEND_BYTE 00h
            SEND_BYTE 00h
            SEND_BYTE 02h
            SEND_BYTE 01h
            READ_BYTE
            READ_BYTE
            mov bh, al
            READ_BYTE
            cmp bh, 00h
            jne SD_Init_Error

SD_Init_Finished:

SD_Init_OK:
            clc
            jmp SD_Init_End
SD_Init_Error:
            stc
SD_Init_End:
            out 0E9h, al
            pop bx
            pop ax
            pop dx
            pop cx
            ret


; -----------------------------------------------------------------
; Read sector from the SD card.
; Input:
;       DX:AX - sector number
;       ES:DI - destination in memory
; -----------------------------------------------------------------

SD_Read:
            push bx
            push ax
            push dx
            push cx
            push ax
            push ax
            push dx
                        
            out 0E8h, al
            mov al, 1       ; Set bit PC0 to 1
            out 23h, al
            
            ; Send CMD17
            SEND_BYTE 51h
            SEND_BYTE 00h
            pop dx
            xchg dl, dh
            SEND_BYTE dh
            pop dx
            SEND_BYTE dh
            pop dx
            SEND_BYTE dl
            SEND_BYTE 01h
            
            ; Wait for "00" response
            mov cx, 10000
SD_Read_Response:
            READ_BYTE
            cmp al, 00h
            je SD_Read_Do
            loop SD_Read_Response
            jmp SD_Read_Error
            
            ; Wait for data token
SD_Read_Do:
            mov cx, 10000
SD_Read_Wait:
            READ_BYTE
            cmp al, 0FEh
            je SD_Read_Continue
            loop SD_Read_Wait
            jmp SD_Read_Error
            
            ; Read sector bytes
SD_Read_Continue:
            SEND_BYTE 0FFh
            mov cx, 512
            ; More efficient routine on NEC V20
            db 60h          ; PUSHA
            stc
            jnc SD_Read_Loop
            db 61h          ; POPA
            mov dx, 00E1h
            db 0F3h, 06Ch   ; REP INSB
            jmp SD_Read_Finished
SD_Read_Loop:
            in al, 0E1h
            stosb
            loop SD_Read_Loop
SD_Read_Finished:
            READ_BYTE
            READ_BYTE
            mov al, 0       ; Set bit PC0 to 0
            out 23h, al
            clc
            jmp SD_Read_End
SD_Read_Error:
            mov al, 0       ; Set bit PC0 to 0
            out 23h, al
			mov ax, Data_Segment
			mov ds, ax
            mov byte [Data_SD], 00h
            stc
SD_Read_End:
            out 0E9h, al
            pop cx
            pop dx
            pop ax
            pop bx
            ret

; -----------------------------------------------------------------
; Write sector to the SD card.
; Input:
;       DX:AX - sector number
;       DS:SI - destination in memory
; -----------------------------------------------------------------

SD_Write:
            push bx
            push ax
            push dx
            push cx
            push ax
            push ax
            push dx
            
            out 0E8h, al
            mov al, 1       ; Set bit PC0 to 1
            out 23h, al

            ; Send CMD24
            SEND_BYTE 58h
            SEND_BYTE 00h
            pop dx
            xchg dl, dh
            SEND_BYTE dh
            pop dx
            SEND_BYTE dh
            pop dx
            SEND_BYTE dl
            SEND_BYTE 01h
            READ_BYTE
            
            ; Wait for "00" response
            mov cx, 10000
SD_Write_Response:
            READ_BYTE
            cmp al, 00h
            je SD_Write_Do
            loop SD_Write_Response
            jmp SD_Write_Error

SD_Write_Do:
            ; Write data token
            SEND_BYTE 0FFh
            SEND_BYTE 0FEh

            ; Write sector bytes
SD_Write_Continue:
            mov cx, 512
            ; More efficient routine on NEC V20
            db 60h          ; PUSHA
            stc
            jnc SD_Write_Loop
            db 61h          ; POPA
            mov dx, 00E0h
            db 0F3h, 06Eh   ; REP OUTSB
            jmp SD_Write_Finished
SD_Write_Loop:
            lodsb
            out 0E0h, al
            loop SD_Write_Loop
SD_Write_Finished:
            ; Dummy CRC checksum
            SEND_BYTE 00h
            SEND_BYTE 00h

            ; Check data response
            READ_BYTE
            mov ah, al
            READ_BYTE
            and ah, 1Fh
            cmp ah, 05h
            jne SD_Write_End

            ; Wait while the card is busy
            mov cx, 30000
SD_Write_Wait:
            READ_BYTE
            cmp al, 0FFh
            je SD_Write_Finish
            loop SD_Write_Wait
            jmp SD_Write_Error

SD_Write_Finish:
            mov al, 0       ; Set bit PC0 to 0
            out 23h, al
            clc
            jmp SD_Write_End
SD_Write_Error:
            mov al, 0       ; Set bit PC0 to 0
            out 23h, al
			mov ax, Data_Segment
			mov ds, ax
            mov byte [Data_SD], 00h
            stc
SD_Write_End:
            out 0E9h, al
            pop cx
            pop dx
            pop ax
            pop bx
            ret

; -----------------------------------------------------------------
; Convert CHS geometry to LBA sector number
; Input:
;       CL - sector number
;       CH - cylinder number
;       DH - head number
; Output:
;       DX:AX - LBA sector
; -----------------------------------------------------------------

SD_CHS:
            nop
            nop
            nop
            push bx
            xchg cl, ch
            mov ax, cx
            mov cl, 6
            shr ah, cl
            mov cl, dh
            xor dx, dx
            mov bx, SD_HEADS
            mul bx
            add al, cl
            adc ah, 00h
            adc dl, 00h
            mov bx, SD_SECTORS
            mul bx
            and ch, 3Fh
            dec ch
            add al, ch
            adc ah, 00h
            adc dl, 00h
            pop bx
            ret
            
; -----------------------------------------------------------------
; Hard disk parameter table
; -----------------------------------------------------------------

SD_DBT:
            db 0
            db 0
            db 0
            db 2
            db SD_SECTORS
            db 0
            db 0
            db 0
            db 0AAh
            db 0
            db 0

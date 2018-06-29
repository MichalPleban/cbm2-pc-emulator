
HDROM_SECTORS equ 140

; --------------------------------------------------------------------------------------
; Handle INT 13 interrupt for ROM hard disk image.
; --------------------------------------------------------------------------------------

HDROM_Handle:
            cmp ah, 02h
            jz HDROM_02
            cmp ah, 08h
            jz HDROM_08
            cmp ah, 15h
            jz HDROM_15
			stc
			mov ah, 0FFh
			retf

; --------------------------------------------------------------------------------------
; Function 08 - return hard disk parameters.
; --------------------------------------------------------------------------------------

HDROM_08:
            mov cx, 41h ; 256 cylinders, 1 sector/cylinder
            mov dx, 02h ; 1 head, 2 disks attached (second one is SD card)
            xor ah, ah
            clc
            retf
            
; --------------------------------------------------------------------------------------
; Function 15 - read disk type.
; --------------------------------------------------------------------------------------

HDROM_15:
            mov ah, 3
            xor cx, cx
            mov dx, 100h ; 256 total sectors
            clc
            retf

; --------------------------------------------------------------------------------------
; Function 02 - read disk sector.
; --------------------------------------------------------------------------------------

HDROM_02:
            push ds
            push di
            mov di, bx
            push bx
            push cx
            push ax
            push dx
            push si
            push bp
            mov bx, 0F000h
            mov ds, bx
            mov bx, [000Ch]
            mov ds, bx
            mov bl, ch
            xor bh, bh
            shl bx, 1
            mov dl, al
HDROM_02_Loop:
            call HDROM_Read
            inc bx
            inc bx
            dec dl
            jnz HDROM_02_Loop
            pop bp
            pop si
            pop dx
            pop ax
            pop cx
            pop bx
            pop di
            pop ds
            clc
            xor ah, ah
            retf

HDROM_Read:
            mov bp, di
            add bp, 512
            mov si, [bx]
            xor ch, ch
            xor ah, ah
HDROM_Loop:
            cmp di, bp
            jnz HDROM_Do
            ret
HDROM_Do:
            lodsb
            test al, 0C0h
            jnz HDROM_NotCopy
            
            ;Copy X bytes verbatim
            mov cl, al
            inc cl
            rep movsb
            jmp HDROM_Loop
            
HDROM_NotCopy:
            test al, 080h
            jnz HDROM_Dict
            
            ; Store X zero bytes
            mov cl, al
            sub cl, 03Fh
            xor al, al
            rep stosb
            jmp HDROM_Loop
            
HDROM_Dict:
            ; Find dictionary item
            push si
            mov si, HDROM_SECTORS*2
            mov ch, al
            and ch, 07Fh
HDROM_Dict_Loop:
            lodsb
            test ch, ch
            jz HDROM_Dict_Found
            add si, ax
            dec ch
            jmp HDROM_Dict_Loop
            
            ; Copy dictionary item
HDROM_Dict_Found:
            mov cl, al
            rep movsb 
            pop si
            jmp HDROM_Loop

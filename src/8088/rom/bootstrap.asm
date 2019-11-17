

; -----------------------------------------------------------------
; Start the ROM code
; -----------------------------------------------------------------

Bootstrap:
            ; Copy the upper ROM & payload to RAM
            call Bootstrap_Copy
            
            in al, 0E4h
            and al, 0DFh
            out 0E4h, al
    		jmp	RomInit

; -----------------------------------------------------------------
; Copy the ROM code to RAM
; -----------------------------------------------------------------

Bootstrap_Copy:
            in al, 0E4h
            or al, 020h
            out 0E4h, al
            mov ax, cs
            mov ds, ax
            mov es, ax
            mov si, RomStart
            mov di, si
            mov cx, RomEnd-RomStart
            rep movsb

%ifdef DEVEL
            ; Development ROM: check if there is already code in RAM
            in al, 0E4h
            and al, 0DFh
            out 0E4h, al
            cmp byte [0000h], 0EAh
            jnz Bootstrap_Copy_1
            cmp word [0001h], 0F000h
            jnz Bootstrap_Copy_1
            cmp word [0003h], 0F000h
            jnz Bootstrap_Copy_1
            ret

Bootstrap_Copy_1:
            in al, 0E4h
            or al, 020h
            out 0E4h, al
%endif
            xor ax, ax
            mov si, ax
            mov di, ax
            mov cx, PayloadEnd
            rep movsb
            ret

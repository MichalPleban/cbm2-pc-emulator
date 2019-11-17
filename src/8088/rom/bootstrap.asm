

; -----------------------------------------------------------------
; Start the ROM code
; -----------------------------------------------------------------

Bootstrap:
            ; Copy the upper ROM & payload to RAM
            call Bootstrap_Copy
            
            call Bootstrap_Init

            mov al, CHAR_CLRSCR
            call Bootstrap_IPC12
            mov al, 11h
            call Bootstrap_IPC22
            
            in al, 0E4h
            and al, 0DFh
            out 0E4h, al
         
    		jmp	RomInit


; -----------------------------------------------------------------
; Initialize IPC vectors for calling the 6509 stub
; -----------------------------------------------------------------

Bootstrap_Init:
            ; Segment for the IPC table
            mov bx, 9FF0h
			push cs
			pop ds
			mov es, bx
			
			; Install the code stub
			xor ax, ax
			mov di, ax
			mov si, Bootstrap_Stub
			mov cx, Bootstrap_Stub_End-Bootstrap_Stub
			rep movsb
			
			; Install parameters for incoming functions
			xor cx, cx
			add di, 0010h
Bootstrap_Init_1:
			mov ax, cx
			stosw
			mov ax, 0F000h
			stosw
			stosw
			inc cx
			cmp cx, 0010h
			jne Bootstrap_Init_1
			
			; Number of parameters for IPC functions 12 and 22
			mov [es:0086h], word 0203h
			mov [es:00E6h], word 000Ah
			
			; Change INT 07 vector
			xor ax, ax
			mov ds, ax
			mov [001Ch], ax
			mov [001Eh], bx			
			
			ret

Bootstrap_Stub:
			pop ax
			pop ax
			popf
			jmp 0F000h:0000h
			db 05Ah
			db 0A5h
Bootstrap_Stub_End:


; -----------------------------------------------------------------
; IPC functions used by bootstrap
; -----------------------------------------------------------------

Bootstrap_IPC12:
			push cx
			push ds
			mov cx, 9FF0h
			mov ds, cx
			mov [000Ah+2], al
			mov cl, 12h
			call 0F000h:0F003h
			pop ds
			pop cx
			ret

Bootstrap_IPC22:
			push cx
			push ds
			mov cx, 9FF0h
			mov ds, cx
			mov [000Ah+2], al
			mov [000Ah+3], byte 0
			pushf
			sti
			mov cl, 0A2h
			call 0F000h:0F003h
			popf
			pop ds
			pop cx
			ret

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

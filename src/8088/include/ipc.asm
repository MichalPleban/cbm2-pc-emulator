

IPCData		equ 000Ah				; Offset of the data trasfer area (16 bytes)

Screen_Segment  equ 0B000h



%macro		IPC_Call 	1
			pushf
			cli
			mov cl, %1
			call IPC
			popf
%endmacro

%macro		IPC_Enter	0
			push cx
			push ds
			call IPC_GetSeg
%endmacro

%macro		IPC_Leave	0
			pop ds
			pop cx
%endmacro

%macro		IPC_Disable_IRQ_old	0
			pushf
			cli
			push ax
			mov al, 0FEh
			out 01h, al
			pop ax
			sti
%endmacro

%macro		IPC_Enable_IRQ_old	0
			cli
			push ax
			push ds
			xor ax, ax
			mov ds, ax
			cmp [0168h], word IPC_IRQ2
			jz %%1
			mov al, 0FEh
			jmp %%2
%%1:
			mov al, 0FAh
%%2:
			out 01h, al
			pop ds
			pop ax
			popf
%endmacro

%macro		IPC_Disable_IRQ	0
			pushf
			cli
			push ax
			in al, 01h
			push ax
			mov al, 0FEh
			out 01h, al
			sti
%endmacro

%macro		IPC_Enable_IRQ	0
			cli
			pop ax
			out 01h, al
			pop ax
			popf
%endmacro

; --------------------------------------------------------------------------------------
; Issue the actual call to the 6509 processor by calling the BIOS
; --------------------------------------------------------------------------------------

IPC:
			call 0F000h:0F003h
			ret

IPC_GetSeg:
			xor cx, cx
			mov ds, cx
			mov cx, [001Eh]
			mov ds, cx
			ret

; --------------------------------------------------------------------------------------
; Initialize interrupt vectors and IPC chip.
; --------------------------------------------------------------------------------------

IPC_Init:
			cli
			
			push ds
			xor ax, ax
			mov ds, ax
			mov ax, cs
			
			; Int 58 vector (IPC) -> original INT 08
			mov [0160h], word 0F1E2h
			mov [0162h], word 0F000h

			; Int 5A vector (TOD timer) -> Timer handler routine
			mov [0168h], word IPC_IRQ2
			mov [016Ah], word ax
			mov [017Ch], word IPC_IRQ_Spurious
			mov [017Eh], word ax

			; Int 08 vector -> Our own handler
			mov [0020h], word INT_08
			mov [0022h], word ax
			
			; Rebase interrupts to 58h, enable IRQ0 and IRQ2
			mov al, 1Bh
			out 00h, al
			mov al, 58h
			out 01h, al
			mov al, 1
			out 01h, al
			mov al, 0FAh
			out 01h, al
			
			pop ds
			sti
			ret

; --------------------------------------------------------------------------------------
; Handle spurious IRQ. It can be either IRQ0 or IRQ2.
; --------------------------------------------------------------------------------------

IPC_IRQ_Spurious:
			push bx
			; Extremely ugly hack to check if IRQ0 occured.
			; Before calling the ROM BIOS code, we disable IRQ2.
			; Therefore, if interrupt occured when the CPU was in the ROM BIOS, 
			; it must be IRQ0.
			mov bx, sp
			cmp [ss:bx+4], word 0F000h
			jnz IPC_IRQ_Spurious_IRQ2
			cmp [ss:bx+6], word 0F000h
			jb IPC_IRQ_Spurious_IRQ2
			cmp [ss:bx+6], word 0F286h
			ja IPC_IRQ_Spurious_IRQ2
			pop bx
			jmp 0F000h:0F1E2h
			
IPC_IRQ_Spurious_IRQ2:
			pop bx

; --------------------------------------------------------------------------------------
; IRQ2 - 500 Hz timer interrupt routine.
; --------------------------------------------------------------------------------------

IPC_IRQ2:
			push ax
			push ds
			mov al, 20h
			out 00h, al

			mov ax, Data_Segment
			mov ds, ax

			mov ax, [Data_Ticks]
			add ax, 182
			cmp ax, 5000 
			jb IPC_IRQ2_Below
			int 08h
			sub ax, 5000
IPC_IRQ2_Below:
			mov [Data_Ticks], ax

			pop ds
			pop ax
			iret

; --------------------------------------------------------------------------------------
; Fake INT 08 - just call INT 1C
; --------------------------------------------------------------------------------------

INT_08:
			int 1Ch
			iret

; --------------------------------------------------------------------------------------
; Find segment where IPC table can be installed.
; Output:
;           BX - segment
; --------------------------------------------------------------------------------------

IPC_FindSegment:
            push ax
            push ds
            
            ; Try in MDA video memory, after the screen buffer
            mov bx, 0B100h
            mov ds, bx
            mov ax, 0A55Ah
            mov [0000h], ax
            cmp ax, [0000h]
            jne IPC_FindSegment_Fail
            neg ax
            mov [0000h], ax
            cmp ax, [0000h]
            jne IPC_FindSegment_Fail
IPC_FindSegment_Ret:            
            pop ds
            pop ax
            ret
            
            ; Return default 0040 if all else fails
IPC_FindSegment_Fail:
            mov bx, 0040h
            jmp IPC_FindSegment_Ret

; --------------------------------------------------------------------------------------
; Install IPC data at segment specified by previous function.
; --------------------------------------------------------------------------------------

IPC_Install:
            call IPC_FindSegment
			push cs
			pop ds
			mov es, bx
			xor ax, ax
			
			; Install the code stub
			mov di, ax
			mov si, IPC_Stub
			mov cx, IPC_Stub_End-IPC_Stub
			rep movsb
			
			; Install parameters for incoming functions
			xor cx, cx
			add di, 0010h
IPC_Install_Loop1:
			mov ax, cx
			stosw
			xor ax, ax
			stosw
			mov ax, 0F000h
			stosw
			inc cx
			cmp cx, 0010h
			jne IPC_Install_Loop1
			
			; Install parameters for outgoing functions
			mov si, IPC_Params
			mov cx, 12h
IPC_Install_Loop2:
			movsw
			add di, 4
			loop IPC_Install_Loop2
			
			; Change INT 07 vector
			xor ax, ax
			mov es, ax
			mov [es:001Ch], ax
			mov [es:001Eh], bx
			ret
			
			
; --------------------------------------------------------------------------------------
; Output character to the printer.
; Input:
;     AL - character code
; --------------------------------------------------------------------------------------

%ifdef STANDALONE

IPC_Reset:
			IPC_Enter
			IPC_Call 18h
			IPC_Leave
			ret
			
%endif

; --------------------------------------------------------------------------------------
; Peek into keyboard buffer.
; Output:
;			ZF - zero flag set if no key in buffer
;			AL - code of key pressed
;			AH - shift status (bit 4 = Shift not pressed, bit 5 = Ctrl not pressed)
; --------------------------------------------------------------------------------------

IPC_KbdPeek:
			IPC_Enter
			IPC_Call 10h
			mov al, [IPCData+1]
			test al, 01
			mov ax, [IPCData+2]
			IPC_Leave
			ret

; --------------------------------------------------------------------------------------
; Clear keyboard buffer.
; Output:
;			AL - code of key pressed
;			AH - shift status (bit 4 = Shift not pressed, bit 5 = Ctrl not pressed)
; WARNING: 
; This function can only be called if there is character in the buffer,
; othwerise it will hang forever!
; --------------------------------------------------------------------------------------

IPC_KbdClear:
			IPC_Enter
			IPC_Call 11h
			mov ax, [IPCData+2]
			IPC_Leave
			ret

; --------------------------------------------------------------------------------------
; Convert CBM key code to PC scan code.
; Input:
;			AL - key code
;			AH - shift flags
; Output:
;			AX - scan code
; --------------------------------------------------------------------------------------

IPC_KbdConvert:
			push ds
			push cx
			mov ch, ah
			mov cl, 3
			xor ch, 30h
			shr ch, cl
			xor ah, ah
			shl ax, cl
			or al, ch
			push bp
			mov bp, ax
			mov ax, [cs:IPC_KbdConvert_Table+bp]
			test ax, ax
			pop bp
			pop cx
			pop ds
			ret
			
; --------------------------------------------------------------------------------------
; Output PETSCII character to the screen.
; Input:
;     		AL - character code
; --------------------------------------------------------------------------------------

IPC_ScreenOut:
			IPC_Enter
			mov [IPCData+2], al
			IPC_Call 12h
			IPC_Leave
			ret

; --------------------------------------------------------------------------------------
; Output CP437 character to the screen.
; Input:
;     		AL - character code
;     		AH - reverse flag (80h = reverse)
; --------------------------------------------------------------------------------------

IPC_ScreenOutPC:
			IPC_Enter
			mov [IPCData+2], byte 3
			mov [IPCData+3], ax
			IPC_Call 1Dh
			IPC_Leave
			ret

; --------------------------------------------------------------------------------------
; Visually simulate that an operation is in progress 
; --------------------------------------------------------------------------------------

IPC_ShowProgress:
			IPC_Enter
			mov [IPCData+2], byte 7
			IPC_Call 1Dh
			IPC_Leave
			ret

; --------------------------------------------------------------------------------------
; Output Escape sequence (Esc, then character) to the screen.
; Input:
;     		AL - character code
; --------------------------------------------------------------------------------------

IPC_ScreenEscape:
			push ax
			mov al, 27
			call IPC_ScreenOut
			pop ax
			call IPC_ScreenOut
			ret

; --------------------------------------------------------------------------------------
; Set screen window (editable area).
; Input:
;			CL - X of upper left corner
;			CH - Y of upper left corner
;			DL - X of lower right corner
;			DH - Y of lower right corner
; --------------------------------------------------------------------------------------

IPC_WindowSet:
			push dx
			mov dx, cx
			call IPC_CursorSet
			mov al, 'T'
			call IPC_ScreenEscape
			pop dx
			call IPC_CursorSet
			mov al, 'B'
			call IPC_ScreenEscape
			ret

; --------------------------------------------------------------------------------------
; Remove screen window - makes whole screen editable.
; --------------------------------------------------------------------------------------

IPC_WindowRemove:
			xor cx, cx
			mov dx, 184Fh
			jmp IPC_WindowSet

; --------------------------------------------------------------------------------------
; Set cursor position on the screen.
; Input:
;     		DH - row
;			DL - column
; --------------------------------------------------------------------------------------

IPC_CursorSet:
			IPC_Enter
			mov [IPCData+2], byte 1
			mov [IPCData+3], dx
			IPC_Call 1Dh
			IPC_Leave
			ret

; --------------------------------------------------------------------------------------
; Read cursor position on the screen.
; Output:
;     		DH - row
;			DL - column
; --------------------------------------------------------------------------------------

IPC_CursorGet:
			IPC_Enter
			mov [IPCData+2], byte 2
			IPC_Call 1Dh
			mov dx, [IPCData+3]
			IPC_Leave
			ret

; --------------------------------------------------------------------------------------
; Initialize the video driver.
; Output:
;           
; --------------------------------------------------------------------------------------

%ifdef SCREEN

IPC_Video_Init:
            push ax
            push ds
            mov ax, 0B000h
            mov ds, ax
            mov [0002h], word 0694Dh
            mov [0004h], word 06843h
            mov [0006h], word 07541h
            pop ds
            pop ax
			IPC_Enter
			mov [IPCData+2], byte 6
			IPC_Disable_IRQ
			mov cl, 9Dh
			call IPC
			IPC_Enable_IRQ
			mov al, [IPCData+2]
			mov dx, [IPCData+3]
			IPC_Leave
			ret

%endif 

; --------------------------------------------------------------------------------------
; Call the video screen conversion routine.
; --------------------------------------------------------------------------------------

%ifdef SCREEN

IPC_Video_Convert:
            push ax
            push ds
            mov ax, 0B000h
            mov ds, ax
            mov ax, word [0000]
            mov word [4000], ax
            pop ds
            pop ax
			IPC_Enter
			mov [IPCData+3], dx
			mov [IPCData+2], byte 5
			IPC_Disable_IRQ
			mov cl, 9Dh
			call IPC
			IPC_Enable_IRQ
			IPC_Leave
			ret

%endif 

; --------------------------------------------------------------------------------------
; Output character to the printer.
; Input:
;     AL - character code
; --------------------------------------------------------------------------------------

IPC_PrinterOut:
			IPC_Enter
			mov [IPCData+2], al
			IPC_Call 13h
			IPC_Leave
			ret

; --------------------------------------------------------------------------------------
; Input character from the serial port.
; Output:
;     AL - character code
; --------------------------------------------------------------------------------------

IPC_SerialIn:
			IPC_Enter
			IPC_Call 19h
			mov al, [IPCData+2]
			IPC_Leave
			ret

; --------------------------------------------------------------------------------------
; Output character to the serial port.
; Input:
;     AL - character code
; --------------------------------------------------------------------------------------

IPC_SerialOut:
			IPC_Enter
			mov [IPCData+2], al
			IPC_Call 1Ah
			IPC_Leave
			ret

; --------------------------------------------------------------------------------------
; Read or write disk sector.
; Input:
;			AH - physical sector number
;			AL - physical track number
;			DL - drive number
;			ES:BX - buffer address
;			BP - 0 = disk read, 1 = disk write
; Return:
;			AX - disk read status from the 8050 drive ("00" = OK)
; --------------------------------------------------------------------------------------
			
IPC_SectorAccess:		
			IPC_Enter
			call IPC_SectorSet
			mov cx, 0096h
			add cx, bp
			IPC_Disable_IRQ
			call IPC
			IPC_Enable_IRQ			
			mov ax, [IPCData+2]
			IPC_Leave
			ret
			
; --------------------------------------------------------------------------------------
; Helper function to set disk access parameters.
; Input:
;			AH - physical sector number
;			AL - physical track number
;			DL - drive number
;			ES:BX - buffer address
; --------------------------------------------------------------------------------------

IPC_SectorSet:
			push bx
			mov [IPCData+2], dl
			mov [IPCData+3], byte 0
			mov [IPCData+4], al
			mov [IPCData+5], byte 0
			mov [IPCData+6], ah
			xchg bl, bh
			mov [IPCData+7], bx
			mov bx, es
			xchg bl, bh
			mov [IPCData+9], bx
			pop bx
			ret

; --------------------------------------------------------------------------------------
; Set system timer.
; Input:
;     DH - hour
;     DL - minute
;     AH - second
;     AL - tenth of seconds
; --------------------------------------------------------------------------------------

IPC_TimeSet:
			IPC_Enter
			xchg dh, dl
			mov [IPCData+0], dx
			xchg ah, al
			mov [IPCData+2], ax
			IPC_Call 1Eh
			IPC_Leave
			ret

; --------------------------------------------------------------------------------------
; Get system timer.
; Output:
;     DH - hour
;     DL - minute
;     AH - second
;     AL - tenth of seconds
; --------------------------------------------------------------------------------------

IPC_TimeGet:
			IPC_Enter
			IPC_Call 1Fh
			mov dx, [IPCData+0]
			xchg dh, dl
			mov ax, [IPCData+2]
			xchg ah, al
			IPC_Leave
			ret

; -----------------------------------------------------------------
; Calculate 8250 physical sector number from logical sector number.
; Input:
;			AX - logical sector number
; Output:
;			AH - physical sector number
;			AL - physical track number
; -----------------------------------------------------------------

IPC_SectorCalc:
			push ds
			push si
			push bx
			; Skip tracks 38 and 39
			cmp ax, 1044
			jl IPC_SectorCalc_0
			add ax, 87
IPC_SectorCalc_0:
			mov bx, ax
			push cs
			pop ds
			mov si, IPC_8250_Layout
IPC_SectorCalc_1:
			lodsw
			cmp bx, ax
			jl IPC_SectorCalc_1
			sub bx, ax
			add si, IPC_8250_Layout_2-IPC_8250_Layout-2
			lodsw
			xchg bx, ax
			div bh
			add al, bl
			pop bx
			pop si
			pop ds
			ret

; --------------------------------------------------------------------------------------
; CBM key code to PC scan code conversion table.
; --------------------------------------------------------------------------------------

IPC_KbdConvert_Table:
			dw 03B00h, 05400h, 05E00h, 06800h ; 00 - F1
			dw 0011Bh, 0011Bh, 0011Bh, 00100h ; 01 - Esc
			dw 00F09h, 00F00h, 09400h, 0A500h ; 02 - Tab
			dw 00000h, 00000h, 00000h, 00000h ; 03
			dw 00000h, 00000h, 00000h, 00000h ; 04
			dw 00000h, 00000h, 00000h, 00000h ; 05
			dw 03C00h, 05500h, 05F00h, 06900h ; 06 - F2
			dw 00231h, 00221h, 00000h, 07800h ; 07 - 1
			dw 01071h, 01051h, 01011h, 01000h ; 08 - Q
			dw 01E61h, 01E41h, 01E01h, 01E00h ; 09 - A
			dw 02C7Ah, 02C5Ah, 02C1Ah, 02C00h ; 0A - Z
			dw 00000h, 00000h, 00000h, 00000h ; 0B
			dw 03D00h, 05600h, 06000h, 06A00h ; 0C - F3
			dw 00332h, 00340h, 00300h, 07900h ; 0D - 2
			dw 01177h, 01157h, 01117h, 01100h ; 0E - W
			dw 01F73h, 01F53h, 01F13h, 01F00h ; 0F - S
			dw 02D78h, 02D58h, 02D18h, 02D00h ; 10 - X
			dw 02E63h, 02E43h, 02E03h, 02E00h ; 11 - C
			dw 00000h, 00000h, 00000h, 00000h ; 12
			dw 00433h, 00423h, 00000h, 07A00h ; 13 - 3
			dw 01265h, 01245h, 01205h, 01200h ; 14 - E
			dw 02064h, 02044h, 02004h, 02000h ; 15 - D
			dw 02166h, 02146h, 02106h, 02100h ; 16 - F
			dw 02F76h, 02F56h, 02F16h, 02F00h ; 17 - V
			dw 03F00h, 05800h, 06200h, 06C00h ; 18 - F5
			dw 00534h, 00524h, 00000h, 07B00h ; 19 - 4
			dw 01372h, 01352h, 01312h, 01300h ; 1A - R
			dw 01474h, 01454h, 01414h, 01400h ; 1B - T
			dw 02267h, 02247h, 02207h, 02200h ; 1C - G
			dw 03062h, 03042h, 03002h, 03000h ; 1D - B
			dw 04000h, 05900h, 06300h, 06D00h ; 1E - F6
			dw 00635h, 00625h, 00000h, 07C00h ; 1F - 5
			dw 00736h, 0075Eh, 0071Eh, 07D00h ; 20 - 6
			dw 01579h, 01559h, 01519h, 01500h ; 21 - Y
			dw 02368h, 02348h, 02308h, 02300h ; 22 - H
			dw 0316Eh, 0314Eh, 0310Eh, 03100h ; 23 - N
			dw 04100h, 05A00h, 06400h, 06E00h ; 24 - F7
			dw 00837h, 00826h, 00000h, 07E00h ; 25 - 7
			dw 01675h, 01655h, 01615h, 01600h ; 26 - U
			dw 0246Ah, 0244Ah, 0240Ah, 02400h ; 27 - J
			dw 0326Dh, 0324Dh, 0320Dh, 03200h ; 28 - M
			dw 03920h, 03920h, 03920h, 03920h ; 29 - Space
			dw 04200h, 05B00h, 06500h, 06F00h ; 2A - F8
			dw 00938h, 0092Ah, 00000h, 07F00h ; 2B - 8
			dw 01769h, 01749h, 01709h, 01700h ; 2C - I
			dw 0256Bh, 0254Bh, 0250Bh, 02500h ; 2D - K
			dw 0332Ch, 0333Ch, 00000h, 00000h ; 2E - ,
			dw 0342Eh, 0343Eh, 00000h, 00000h ; 2F - .
			dw 04300h, 05C00h, 06600h, 07000h ; 30 - F9
			dw 00A39h, 00A28h, 00000h, 08000h ; 31 - 9
			dw 0186Fh, 0184Fh, 0180Fh, 01800h ; 32 - O
			dw 0266Ch, 0264Ch, 0260Ch, 02600h ; 33 - L
			dw 0273Bh, 0273Ah, 00000h, 02700h ; 34 - ;
			dw 0352Fh, 0353Fh, 00000h, 00000h ; 35 - /
			dw 04400h, 05D00h, 06700h, 07100h ; 36 - F10
			dw 00B30h, 00B29h, 00000h, 08100h ; 37
			dw 00C2Dh, 00C5Fh, 00C1Fh, 08200h ; 38 - -
			dw 01970h, 01950h, 01910h, 01900h ; 39 - P
			dw 01A5Bh, 01A7Bh, 01A1Bh, 01A00h ; 3A - [
			dw 02827h, 02822h, 00000h, 00000h ; 3B - '
			dw 05000h, 05032h, 09100h, 0A000h ; 3C - cursor down
			dw 00D3Dh, 00D2Bh, 00000h, 08300h ; 3D - =
			dw 02B5Ch, 02B7Ch, 02B1Ch, 02600h ; 3E - <-
			dw 01B5Dh, 01B7Dh, 01B1Dh, 01B00h ; 3F - ]
			dw 01C0Dh, 01C0Dh, 01C0Ah, 0A600h ; 40 - Return
			dw 02960h, 0297Eh, 00000h, 00000h ; 41 - PI
			dw 04800h, 04838h, 08D00h, 09800h ; 42 - cursor up
			dw 04B00h, 04B34h, 07300h, 09B00h ; 43 - cursor left
			dw 04D00h, 04D36h, 07400h, 09D00h ; 44 - cursor right
			dw 00E08h, 00E08h, 00E7Fh, 00E00h ; 45 - Ins Del
			dw 00000h, 00000h, 00000h, 00000h ; 46 - C=
			dw 00000h, 00000h, 00000h, 00000h ; 47
			dw 08500h, 08700h, 08900h, 08B00h ; 48 - Clr Home
			dw 0353Fh, 0353Fh, 00000h, 00000h ; 49 - numerical ?
			dw 04700h, 04737h, 07700h, 09700h ; 4A - numerical 7
			dw 04B00h, 04B34h, 07300h, 09B00h ; 4B - numerical 4
			dw 04F00h, 04F31h, 07500h, 09F00h ; 4C - numerical 1
			dw 00B30h, 00B29h, 00000h, 08100h ; 4D - numerical 0
			dw 08600h, 08800h, 08A00h, 08C00h ; 4E - Rvs Off
			dw 00000h, 00000h, 00000h, 00000h ; 4F - numerical CE
			dw 04800h, 04838h, 08D00h, 09800h ; 50 - numerical 8
			dw 04C35h, 04C35h, 08F00h, 00000h ; 51 - numerical 5
			dw 05000h, 05032h, 09100h, 0A000h ; 52 - numerical 2
			dw 05300h, 0532Eh, 09300h, 0A300h ; 53 - numerical .
			dw 07200h, 07200h, 07200h, 07200h ; 54 - Norm Graph
			dw 0372Ah, 00000h, 09600h, 03700h ; 55 - numerical *
			dw 04900h, 04939h, 08400h, 09900h ; 56 - numerical 9
			dw 04D00h, 04D36h, 07400h, 09D00h ; 57 - numerical 6
			dw 05100h, 05133h, 07600h, 0A100h ; 58 - numerical 3
			dw 05200h, 05230h, 09200h, 0A200h ; 59 - numerical 00
			dw 02E03h, 02E03h, 02E03h, 02E03h ; 5A - Run Stop
			dw 0352Fh, 0352Fh, 09500h, 0A400h ; 5B - numerical /
			dw 04A2Dh, 04A2Dh, 08E00h, 04A00h ; 5C - numerical -
			dw 04E2Bh, 04E2Bh, 00000h, 04E00h ; 5D - numerical +
			dw 01C0Dh, 01C0Dh, 01C0Ah, 0A600h ; 5E - numerical Enter

; -----------------------------------------------------------------
; Data describing 8250 disk layout.
; -----------------------------------------------------------------

IPC_8250_Layout:
			dw	3867
			dw	3592
			dw	3214
			dw	2083
			dw	1784
			dw	1509
			dw	1131
			dw	0
IPC_8250_Layout_2:
			db	142, 23
			db	131, 25
			db	117, 27
			db	78, 29
			db	65, 23
			db	54, 25
			db	40, 27
			db	1, 29

; -----------------------------------------------------------------
; Code stub to put at INT 07 pointer.
; -----------------------------------------------------------------

IPC_Stub:
			pop ax
			pop ax
			popf
			jmp 0F000h:0000h
			db 05Ah
			db 0A5h
IPC_Stub_End:

; -----------------------------------------------------------------
; List of numbers of parameters for IPC functions.
; -----------------------------------------------------------------

IPC_Params:
			db 0, 4
			db 0, 4
			db 3, 2
			db 3, 2
			db 3, 2
			db 0, 3
			db 11, 4
			db 11, 4
			db 0, 4
			db 0, 3
			db 3, 2
			db 5, 2
			db 0, 0
			db 5, 5
			db 4, 0
			db 0, 4
			db 0, 0
			db 11, 4
			


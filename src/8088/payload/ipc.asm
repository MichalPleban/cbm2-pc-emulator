

IPCData     equ 000Ah                ; Offset of the data trasfer area (16 bytes)


%macro      IPC_Call     1
            mov cl, %1
            call IPC
%endmacro

%macro      IPC_Enter    0
            pushf
            cli
            push cx
            push ds
            out 0E8h, al
            call IPC_GetSeg
%endmacro

%macro      IPC_Leave    0
            out 0E9h, al
            pop ds
            pop cx
            popf
%endmacro

%macro      IPC_Disable_IRQ    0
            push ax
            in al, 01h
            push ax
            mov al, 0FEh
            out 01h, al
            sti
%endmacro

%macro      IPC_Enable_IRQ    0
            cli
            pop ax
            out 01h, al
            pop ax
%endmacro

; --------------------------------------------------------------------------------------
; Issue the actual call to the 6509 processor by calling the BIOS
; --------------------------------------------------------------------------------------

IPC:
            push ax
IPC_Busy:
            in al, 20h
            test al, 10h
            jz IPC_Busy
            pop ax
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

            ; Int 5A vector (60 Hz timer)
            mov [0168h], word IPC_IRQ2
            mov [016Ah], ax
            
            ; Int 5F vector (18.2 Hz timer) -> Timer handler routine
            mov [017Ch], word IPC_IRQ7
            mov [017Eh], ax

            ; Int 08 vector -> Our own handler
            mov [0020h], word INT_08
            mov [0022h], ax
            
            ; Int 0C vector (COM1 interrupt)
            mov [0030h], word INT_Iret
            mov [0032h], ax
            
            ; Int 09 vector (keyboard interrupt)
            mov [0024h], word INT_Iret
            mov [0026h], ax
            
            ; Rebase interrupts to 58h, enable IRQ0, IRQ2 and IRQ7
            out 0E8h, al
            mov al, 13h
            out 00h, al
            mov al, 58h
            out 01h, al
            mov al, 1
            out 01h, al
            mov al, 07Ah
            out 01h, al
            out 0E9h, al
            
            pop ds
            sti
            ret


; --------------------------------------------------------------------------------------
; IRQ7 - 18.2 Hz timer interrupt routine.
; --------------------------------------------------------------------------------------

IPC_IRQ7:
            push ax
            push ds
            
            ; EOI to the PIC chip
            out 0E8h, al
            mov al, 20h
            out 00h, al
            out 0E9h, al
            
            ; Refresh screen
            call Screen_Interrupt
            
            ; Call periodic interrupt
            int 08h
            
            pop ds
            pop ax
            iret

; --------------------------------------------------------------------------------------
; IRQ2 - 60 Hz timer interrupt routine.
; --------------------------------------------------------------------------------------

IPC_IRQ2:
            push ax
            push ds
            
            ; Restore NMI vector
            xor ax, ax
            mov ds, ax
            mov [0008h], word Virtual_Handle
            mov ax, cs
            mov [000Ah], ax
            
            out 0E8h, al
            ; Disable futher interrupts
            in al, 01h
            push ax
            mov al, 0FEh
            out 01h, al
            ; EOI to the PIC chip
            mov al, 20h
            out 00h, al
            out 0E9h, al

            ; Set Shift/Ctrl/Alt key flags
            call INT_16_02    

            ; Interrupt on serial data received
            mov ax, Virtual_Segment
            mov ds, ax
IPC_IRQ2_CheckSerial:
            out 0E8h, al
            in al, 21h
            out 0E9h, al
            test al, 02h
            jnz IPC_IRQ2_NoSerial
            mov [V_Serial_Received], byte 80h
            int 0Ch
            cmp [V_Serial_Received], byte 80h
            jnz IPC_IRQ2_CheckSerial
IPC_IRQ2_NoSerial:

            ; Restore interrupts
            out 0E8h, al
            pop ax
            out 01h, al
            out 0E9h, al

            pop ds
            pop ax
            iret

; --------------------------------------------------------------------------------------
; Fake INT 08 - increase counter and call INT 1C
; --------------------------------------------------------------------------------------

INT_08:
            push ax
            push ds
            xor ax, ax
            mov ds, ax
            call IPC_CounterRead
            add ax, [046Ch]
            mov [046Ch], ax
            mov ax, [046Eh]
            adc ax, 0
            cmp ax, 24
            jb INT_08_1
            xor ax, ax
INT_08_1:
            mov [046Eh], ax
            pop ds
            pop ax
            int 1Ch
INT_Iret:
            iret


; --------------------------------------------------------------------------------------
; Install IPC data at the top memory location
; --------------------------------------------------------------------------------------

IPC_Install:
            mov bx, MemTop-40h           ; Top of the memory
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
            mov ax, 0F000h
            stosw
            stosw
            inc cx
            cmp cx, 0010h
            jne IPC_Install_Loop1
            
            ; Install parameters for outgoing functions
            mov si, IPC_Params
            mov cx, 13h
IPC_Install_Loop2:
            movsw
            add di, 4
            loop IPC_Install_Loop2
            
            ; Change INT 07 vector
            xor ax, ax
            mov es, ax
            mov [es:001Ch], ax
            mov [es:001Eh], bx
            
            ; Install some fake BIOS variables
            
            mov [es:0410h], word 037Dh    ; Equipment flags
            mov [es:0417h], ax            ; Shift flags #1 & #2
            mov [es:0449h], byte 07       ; Current video mode
            mov [es:044Ah], word 80       ; Number of screen columns
            mov [es:044Ch], word 4096     ; Screen size in bytes
            mov [es:044Eh], word 0        ; Screen page offset
            mov [es:0462h], byte 0        ; Display page number
            mov [es:0463h], word 03B4h    ; CRTC port
            mov [es:046Ch], ax            ; Tick count low word
            mov [es:046Eh], ax            ; Tick count high word
            mov [es:048Ah], byte 01       ; Display combination code
            call Clock_Init
            
            ret
            
; --------------------------------------------------------------------------------------
; Set tick counter according to the I2C clock
; --------------------------------------------------------------------------------------

Clock_Init:
            call INT_1A_02_Do
            mov al, dh
            call ConvertFromBCD
            mov ah, al          ; AH = Seconds
            push ax
            mov al, cl
            call ConvertFromBCD
            mov dl, al          ; DL = Minutes
            mov al, ch
            call ConvertFromBCD
            mov dh, al          ; DH = Hours
            pop ax
            xor al, al          ; AL = Microseconds

            ; Calculate number of ticks in whole minutes
            mov bx, ax
            mov al, dh
            mov cl, 60
            mul cl
            xor dh, dh
            add ax, dx
            mov cx, 1092 ; Ticks per minute
            mul cx
            push dx
            push ax
            
            ; Calculate number of ticks in seconds
            mov al, bh
            mov cl, 10
            mul cl
            xor bh, bh
            add ax, bx
            mov cx, 182
            mul cx
            mov cx, 100
            div cx
            
            ; Add them together
            pop cx
            add cx, ax
            pop dx
            xor ax, ax
            adc dx, ax
            
            mov [es:046Ch], cx
            mov [es:046Eh], dx
            ret
            
; --------------------------------------------------------------------------------------
; Initialize the IPC library.
; --------------------------------------------------------------------------------------

IPC_Reset:
            IPC_Enter
            IPC_Call 18h
            IPC_Leave
            ret
            
; --------------------------------------------------------------------------------------
; Peek into keyboard buffer.
; Output:
;           AL - code of key pressed (zero if none)
;           AH - status:
;               bit 0 = a key is pressed
;               bit 4 = Shift not pressed
;               bit 5 = Ctrl not pressed;
;               bit 3 = C= not pressed)
; --------------------------------------------------------------------------------------

IPC_KbdPeek:
            IPC_Enter
            IPC_Call 10h
            mov ax, [IPCData+2]
            or ah, 01h
            and ah, [IPCData+1]
            IPC_Leave
            ret

; --------------------------------------------------------------------------------------
; Clear keyboard buffer.
; Output:
;           AL - code of key pressed
;           AH - shift status (bit 4 = Shift not pressed, bit 5 = Ctrl not pressed, bit 3 = C= not pressed)
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
;           AL - key code
;           AH - shift flags
; Output:
;           AX - scan code
; --------------------------------------------------------------------------------------

IPC_KbdConvert:
            push ds
            push cx
            mov cx, 3
            test ah, 10h
            jnz IPC_KbdConvert_NoShift
            mov ch, 2
IPC_KbdConvert_NoShift:
            test ah, 20h
            jnz IPC_KbdConvert_NoCtrl
            mov ch, 4
IPC_KbdConvert_NoCtrl:
            test ah, 08h
            jnz IPC_KbdConvert_NoAlt
            mov ch, 6
IPC_KbdConvert_NoAlt:
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
;           AL - character code
; --------------------------------------------------------------------------------------

IPC_ScreenOut:
            IPC_Enter
            mov [IPCData+2], al
            IPC_Call 12h
            IPC_Leave
            ret


; --------------------------------------------------------------------------------------
; Initialize the video driver.
; --------------------------------------------------------------------------------------

IPC_Video_Init:
            IPC_Enter
            mov [IPCData], byte 0
            IPC_Disable_IRQ
            mov cl, 94h
            call IPC
            IPC_Enable_IRQ
            IPC_Leave
            ret

; --------------------------------------------------------------------------------------
; Set cursor position on the screen.
; Input:
;           DH - row
;           DL - column
; --------------------------------------------------------------------------------------

IPC_Video_CursorSet:
            IPC_Enter
            mov [IPCData], byte 1
            mov [IPCData+1], dx
            IPC_Disable_IRQ
            mov cl, 94h
            call IPC
            IPC_Enable_IRQ
            IPC_Leave
            ret

; --------------------------------------------------------------------------------------
; Call the video screen conversion routine.
; Input:
;           BL - video page
;           BH - flags describing changed screen areas
; --------------------------------------------------------------------------------------

IPC_Video_Convert:
            push dx
            push ax
            push ds
            mov ax, 0B000h
            add ah, bl
            mov ds, ax
            mov dx, word [0000]
            pop ds
            pop ax
            IPC_Enter
            mov [IPCData+1], bx
            mov [IPCData+3], dx
            mov [IPCData], byte 2
            IPC_Disable_IRQ
            mov cl, 94h
            call IPC
            IPC_Enable_IRQ
            IPC_Leave
            pop dx
            ret

; --------------------------------------------------------------------------------------
; Clear screen
; --------------------------------------------------------------------------------------

IPC_Video_Clear:
            IPC_Enter
            mov [IPCData], byte 3
            mov [IPCData+1], bl
            IPC_Disable_IRQ
            mov cl, 94h
            call IPC
            IPC_Enable_IRQ
            IPC_Leave
            ret

; --------------------------------------------------------------------------------------
; Scroll screen one line up
; --------------------------------------------------------------------------------------

IPC_Video_ScrollUp:
            IPC_Enter
            mov [IPCData], byte 4
            mov [IPCData+1], bl
            IPC_Disable_IRQ
            mov cl, 94h
            call IPC
            IPC_Enable_IRQ
            IPC_Leave
            ret

; --------------------------------------------------------------------------------------
; Enable or disable cursor
; Input:
;           AL = 80 to disable cursor, 00 to enable
; --------------------------------------------------------------------------------------

IPC_Video_SetCursor:
            IPC_Enter
            mov [IPCData], byte 5
            mov [IPCData+1], al
            IPC_Disable_IRQ
            mov cl, 94h
            call IPC
            IPC_Enable_IRQ
            IPC_Leave
            ret
            
; --------------------------------------------------------------------------------------
; Set video display options
; Input:
;           AL = 80 - enable MDA blink, 00 - disable blink
; --------------------------------------------------------------------------------------

IPC_Video_SetOptions:
            IPC_Enter
            mov [IPCData], byte 6
            mov [IPCData+1], al
            mov cl, 14h
            call IPC
            IPC_Leave
            ret

; --------------------------------------------------------------------------------------
; Output character to the printer.
; Input:
;           AL - character code
; --------------------------------------------------------------------------------------

IPC_PrinterOut:
            IPC_Enter
            mov [IPCData+2], al
            IPC_Call 13h
            IPC_Leave
            ret

; --------------------------------------------------------------------------------------
; Read and reset 18.6Hz counter value
; Output:
;           AX - numer of 18.6Hz ticks elapsed since the last call.
; --------------------------------------------------------------------------------------

IPC_CounterRead:
            IPC_Enter
            IPC_Call 15h
            mov ax, [IPCData+2]
            IPC_Leave
            ret

; --------------------------------------------------------------------------------------
; Input character from the serial port.
; Output:
;           AL - character code
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
;           AL - character code
; --------------------------------------------------------------------------------------

IPC_SerialOut:
            IPC_Enter
            mov [IPCData+2], al
            IPC_Call 1Ah
            IPC_Leave
            ret

; --------------------------------------------------------------------------------------
; Set serial port speed and other parameters
; Input:
;           AX - parameters
; --------------------------------------------------------------------------------------

IPC_SerialParams:
            IPC_Enter
            mov [IPCData+2], ax
            IPC_Call 1Bh
            IPC_Leave
            ret

; --------------------------------------------------------------------------------------
; Check the serial port status.
; Output:
;           AL - number of character in the serial buffer
; --------------------------------------------------------------------------------------

IPC_SerialStatus:
            IPC_Enter
            IPC_Call 1Ch
            mov al, [IPCData+2]
            IPC_Leave
            ret

; --------------------------------------------------------------------------------------
; Convert PC serial parameters to CBM-II parameters
; Input:
;           AL - PC parameters
; Output:
;           AX - CBM-II parameters
; --------------------------------------------------------------------------------------

IPC_SerialConvert:
            push bp
            xor ah, ah
            shl ax, 1
            mov bp, ax
            mov ax, [cs:IPC_SerialConvert_Table+bp]
            pop bp
            ret
            
; --------------------------------------------------------------------------------------
; Play a tone using the SID chip.
; Input:
;           AX - frequency
;           DL - 01 = sound enable, 00 = sound disable
; --------------------------------------------------------------------------------------

IPC_Sound:
            IPC_Enter
            mov [IPCData+2], ax
            mov [IPCData+4], dl
            IPC_Call 1Dh
            IPC_Leave
            ret

; --------------------------------------------------------------------------------------
; Read or write disk sector.
; Input:
;           AH - physical sector number
;           AL - physical track number
;           DL - drive number
;           ES:BX - buffer address
;            BP - 0 = disk read, 1 = disk write
; Return:
;           AX - disk read status from the 8050 drive ("00" = OK)
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
;           AH - physical sector number
;           AL - physical track number
;           DL - drive number
;           ES:BX - buffer address
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


; -----------------------------------------------------------------
; Calculate 8250 physical sector number from logical sector number.
; Input:
;           AX - logical sector number
; Output:
;           AH - physical sector number
;           AL - physical track number
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
            dw 00000h, 00000h, 00000h, 00000h ; 03 - Shift Lock (unused)
            dw 00000h, 00000h, 00000h, 00000h ; 04 - Left Shift (unused)
            dw 00000h, 00000h, 00000h, 00000h ; 05 - Ctrl (unused)
            dw 03C00h, 05500h, 05F00h, 06900h ; 06 - F2
            dw 00231h, 00221h, 0FF00h, 07800h ; 07 - 1
            dw 01071h, 01051h, 01011h, 01000h ; 08 - Q
            dw 01E61h, 01E41h, 01E01h, 01E00h ; 09 - A
            dw 02C7Ah, 02C5Ah, 02C1Ah, 02C00h ; 0A - Z
            dw 00000h, 00000h, 00000h, 00000h ; 0B - Right Shift (unused)
            dw 03D00h, 05600h, 06000h, 06A00h ; 0C - F3
            dw 00332h, 00340h, 00300h, 07900h ; 0D - 2
            dw 01177h, 01157h, 01117h, 01100h ; 0E - W
            dw 01F73h, 01F53h, 01F13h, 01F00h ; 0F - S
            dw 02D78h, 02D58h, 02D18h, 02D00h ; 10 - X
            dw 02E63h, 02E43h, 02E03h, 02E00h ; 11 - C
            dw 03E00h, 05700h, 06100h, 06B00h ; 12 - F4
            dw 00433h, 00423h, 0FF00h, 07A00h ; 13 - 3
            dw 01265h, 01245h, 01205h, 01200h ; 14 - E
            dw 02064h, 02044h, 02004h, 02000h ; 15 - D
            dw 02166h, 02146h, 02106h, 02100h ; 16 - F
            dw 02F76h, 02F56h, 02F16h, 02F00h ; 17 - V
            dw 03F00h, 05800h, 06200h, 06C00h ; 18 - F5
            dw 00534h, 00524h, 0FF00h, 07B00h ; 19 - 4
            dw 01372h, 01352h, 01312h, 01300h ; 1A - R
            dw 01474h, 01454h, 01414h, 01400h ; 1B - T
            dw 02267h, 02247h, 02207h, 02200h ; 1C - G
            dw 03062h, 03042h, 03002h, 03000h ; 1D - B
            dw 04000h, 05900h, 06300h, 06D00h ; 1E - F6
            dw 00635h, 00625h, 0FF00h, 07C00h ; 1F - 5
            dw 00736h, 0075Eh, 0071Eh, 07D00h ; 20 - 6
            dw 01579h, 01559h, 01519h, 01500h ; 21 - Y
            dw 02368h, 02348h, 02308h, 02300h ; 22 - H
            dw 0316Eh, 0314Eh, 0310Eh, 03100h ; 23 - N
            dw 04100h, 05A00h, 06400h, 06E00h ; 24 - F7
            dw 00837h, 00826h, 0FF00h, 07E00h ; 25 - 7
            dw 01675h, 01655h, 01615h, 01600h ; 26 - U
            dw 0246Ah, 0244Ah, 0240Ah, 02400h ; 27 - J
            dw 0326Dh, 0324Dh, 0320Dh, 03200h ; 28 - M
            dw 03920h, 03920h, 03920h, 03920h ; 29 - Space
            dw 04200h, 05B00h, 06500h, 06F00h ; 2A - F8
            dw 00938h, 0092Ah, 0FF00h, 07F00h ; 2B - 8
            dw 01769h, 01749h, 01709h, 01700h ; 2C - I
            dw 0256Bh, 0254Bh, 0250Bh, 02500h ; 2D - K
            dw 0332Ch, 0333Ch, 0FF00h, 0FF00h ; 2E - ,
            dw 0342Eh, 0343Eh, 0FF00h, 0FF00h ; 2F - .
            dw 04300h, 05C00h, 06600h, 07000h ; 30 - F9
            dw 00A39h, 00A28h, 0FF00h, 08000h ; 31 - 9
            dw 0186Fh, 0184Fh, 0180Fh, 01800h ; 32 - O
            dw 0266Ch, 0264Ch, 0260Ch, 02600h ; 33 - L
            dw 0273Bh, 0273Ah, 0FF00h, 02700h ; 34 - ;
            dw 0352Fh, 0353Fh, 0FF00h, 0FF00h ; 35 - /
            dw 04400h, 05D00h, 06700h, 07100h ; 36 - F10
            dw 00B30h, 00B29h, 0FF00h, 08100h ; 37 - 0
            dw 00C2Dh, 00C5Fh, 00C1Fh, 08200h ; 38 - -
            dw 01970h, 01950h, 01910h, 01900h ; 39 - P
            dw 01A5Bh, 01A7Bh, 01A1Bh, 01A00h ; 3A - [
            dw 02827h, 02822h, 0FF00h, 0FF00h ; 3B - '
            dw 05000h, 05032h, 09100h, 0A000h ; 3C - cursor down
            dw 00D3Dh, 00D2Bh, 0FF00h, 08300h ; 3D - =
            dw 02B5Ch, 02B7Ch, 02B1Ch, 02600h ; 3E - <-             \|
            dw 01B5Dh, 01B7Dh, 01B1Dh, 01B00h ; 3F - ]
            dw 01C0Dh, 01C0Dh, 01C0Ah, 0A600h ; 40 - Return
            dw 02960h, 0297Eh, 0FF00h, 0FF00h ; 41 - PI             `~
            dw 04800h, 04838h, 08D00h, 09800h ; 42 - cursor up
            dw 04B00h, 04B34h, 07300h, 09B00h ; 43 - cursor left
            dw 04D00h, 04D36h, 07400h, 09D00h ; 44 - cursor right
            dw 00E08h, 00E08h, 00E7Fh, 00E00h ; 45 - Ins Del        BackSpace
            dw 0FF00h, 0FF00h, 0FF00h, 0FF00h ; 46 - C=
            dw 0FF00h, 0FF00h, 0FF00h, 0FF00h ; 47
            dw 08500h, 08700h, 08900h, 08B00h ; 48 - Clr Home       F11
            dw 0353Fh, 0353Fh, 0FF00h, 0FF00h ; 49 - numerical ?    /
            dw 04700h, 04737h, 07700h, 09700h ; 4A - numerical 7    Home
            dw 04B00h, 04B34h, 07300h, 09B00h ; 4B - numerical 4    cursor left
            dw 04F00h, 04F31h, 07500h, 09F00h ; 4C - numerical 1    End
            dw 05200h, 05230h, 09200h, 0A200h ; 59 - numerical 0   Insert
            dw 08600h, 08800h, 08A00h, 08C00h ; 4E - Rvs Off        F12
            dw 0FF00h, 0FF00h, 0FF00h, 0FF00h ; 4F - numerical CE
            dw 04800h, 04838h, 08D00h, 09800h ; 50 - numerical 8    cursor up
            dw 04C35h, 04C35h, 08F00h, 0FF00h ; 51 - numerical 5    5
            dw 05000h, 05032h, 09100h, 0A000h ; 52 - numerical 2    cursor down
            dw 05300h, 0532Eh, 09300h, 0A300h ; 53 - numerical .    Del
            dw 07200h, 07200h, 07200h, 07200h ; 54 - Norm Graph     Print Screen
            dw 0372Ah, 0FF00h, 09600h, 03700h ; 55 - numerical *    *
            dw 04900h, 04939h, 08400h, 09900h ; 56 - numerical 9    PageUp
            dw 04D00h, 04D36h, 07400h, 09D00h ; 57 - numerical 6    cursor right
            dw 05100h, 05133h, 07600h, 0A100h ; 58 - numerical 3    Page Down
            dw 00B30h, 00B29h, 0FF00h, 08100h ; 4D - numerical 00   0
            dw 02E03h, 02E03h, 02E03h, 02E03h ; 5A - Run Stop       Ctrl+C
            dw 0352Fh, 0352Fh, 09500h, 0A400h ; 5B - numerical /    /
            dw 04A2Dh, 04A2Dh, 08E00h, 04A00h ; 5C - numerical -    -
            dw 04E2Bh, 04E2Bh, 0FF00h, 04E00h ; 5D - numerical +    +
            dw 01C0Dh, 01C0Dh, 01C0Ah, 0A600h ; 5E - numerical Enter Enter

; -----------------------------------------------------------------
; Data describing 8250 disk layout.
; -----------------------------------------------------------------

IPC_8250_Layout:
            dw    3867
            dw    3592
            dw    3214
            dw    2083
            dw    1784
            dw    1509
            dw    1131
            dw    0
IPC_8250_Layout_2:
            db    142, 23
            db    131, 25
            db    117, 27
            db    78, 29
            db    65, 23
            db    54, 25
            db    40, 27
            db    1, 29

; --------------------------------------------------------------------------------------
; INT 14, 00 parameters to CBM-II parameters conversion table.
; --------------------------------------------------------------------------------------

IPC_SerialConvert_Table:
            dw 00073h, 00053h, 00033h, 00013h, 000F3h, 000D3h, 000B3h, 00093h
            dw 02073h, 02053h, 02033h, 02013h, 020F3h, 020D3h, 020B3h, 02093h
            dw 00073h, 00053h, 00033h, 00013h, 000F3h, 000D3h, 000B3h, 00093h
            dw 06073h, 06053h, 06033h, 06013h, 060F3h, 060D3h, 060B3h, 06093h
            dw 00075h, 00055h, 00035h, 00015h, 000F5h, 000D5h, 000B5h, 00095h
            dw 02075h, 02055h, 02035h, 02015h, 020F5h, 020D5h, 020B5h, 02095h
            dw 00075h, 00055h, 00035h, 00015h, 000F5h, 000D5h, 000B5h, 00095h
            dw 06075h, 06055h, 06035h, 06015h, 060F5h, 060D5h, 060B5h, 06095h
            dw 00076h, 00056h, 00036h, 00016h, 000F6h, 000D6h, 000B6h, 00096h
            dw 02076h, 02056h, 02036h, 02016h, 020F6h, 020D6h, 020B6h, 02096h
            dw 00076h, 00056h, 00036h, 00016h, 000F6h, 000D6h, 000B6h, 00096h
            dw 06076h, 06056h, 06036h, 06016h, 060F6h, 060D6h, 060B6h, 06096h
            dw 00077h, 00057h, 00037h, 00017h, 000F7h, 000D7h, 000B7h, 00097h
            dw 02077h, 02057h, 02037h, 02017h, 020F7h, 020D7h, 020B7h, 02097h
            dw 00077h, 00057h, 00037h, 00017h, 000F7h, 000D7h, 000B7h, 00097h
            dw 06077h, 06057h, 06037h, 06017h, 060F7h, 060D7h, 060B7h, 06097h
            dw 00078h, 00058h, 00038h, 00018h, 000F8h, 000D8h, 000B8h, 00098h
            dw 02078h, 02058h, 02038h, 02018h, 020F8h, 020D8h, 020B8h, 02098h
            dw 00078h, 00058h, 00038h, 00018h, 000F8h, 000D8h, 000B8h, 00098h
            dw 06078h, 06058h, 06038h, 06018h, 060F8h, 060D8h, 060B8h, 06098h
            dw 0007Ah, 0005Ah, 0003Ah, 0001Ah, 000FAh, 000DAh, 000BAh, 0009Ah
            dw 0207Ah, 0205Ah, 0203Ah, 0201Ah, 020FAh, 020DAh, 020BAh, 0209Ah
            dw 0007Ah, 0005Ah, 0003Ah, 0001Ah, 000FAh, 000DAh, 000BAh, 0009Ah
            dw 0607Ah, 0605Ah, 0603Ah, 0601Ah, 060FAh, 060DAh, 060BAh, 0609Ah
            dw 0007Ch, 0005Ch, 0003Ch, 0001Ch, 000FCh, 000DCh, 000BCh, 0009Ch
            dw 0207Ch, 0205Ch, 0203Ch, 0201Ch, 020FCh, 020DCh, 020BCh, 0209Ch
            dw 0007Ch, 0005Ch, 0003Ch, 0001Ch, 000FCh, 000DCh, 000BCh, 0009Ch
            dw 0607Ch, 0605Ch, 0603Ch, 0601Ch, 060FCh, 060DCh, 060BCh, 0609Ch
            dw 0007Eh, 0005Eh, 0003Eh, 0001Eh, 000FEh, 000DEh, 000BEh, 0009Eh
            dw 0207Eh, 0205Eh, 0203Eh, 0201Eh, 020FEh, 020DEh, 020BEh, 0209Eh
            dw 0007Eh, 0005Eh, 0003Eh, 0001Eh, 000FEh, 000DEh, 000BEh, 0009Eh
            dw 0607Eh, 0605Eh, 0603Eh, 0601Eh, 060FEh, 060DEh, 060BEh, 0609Eh
			
; --------------------------------------------------------------------------------------
; 8250 UART divisor table
; --------------------------------------------------------------------------------------
			
IPC_Serial_Divisor:
			dw 0006h ; 19200
			dw 000Ch ; 9600
			dw 0010h ; 7200
			dw 0018h ; 4800
			dw 0020h ; 3600
			dw 0030h ; 2400
			dw 0040h ; 1800
			dw 0060h ; 1200
			dw 00C0h ; 600
			dw 0180h ; 300
			dw 0300h ; 150
			dw 0354h ; 135
			dw 0417h ; 110
			dw 0600h ; 75
			dw 0900h ; 50
			dw 0FFFFh			
			
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
            db 1, 4     ; 10 - keyboard peek
            db 1, 4     ; 11 - keyboard get
            db 3, 2     ; 12 - screen out
            db 3, 2     ; 13 - printer out
            db 6, 6     ; 14 - screen driver
            db 1, 4     ; 15 - counter read
            db 11, 4    ; 96 - disk read
            db 11, 4    ; 97 - disk write
            db 0, 4     ; 18 - initialize
            db 0, 3     ; 19 - serial in
            db 3, 2     ; 1A - serial out
            db 5, 2     ; 1B - serial config
            db 0, 3     ; 1C - serial status
            db 5, 2     ; 1D - sound output
            db 0, 0
            db 0, 0
            db 0, 0     ; 20 - keyboard clear
            db 11, 4    ; 21 - disk format
            db 10, 0    ; 22 - load 6509 code
            


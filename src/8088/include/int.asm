

CHAR_CLRSCR	equ 147
CHAR_RVSON	equ 18
CHAR_RVSOFF	equ 146
CHAR_DEL	equ	20
CHAR_DOWN	equ	17

; -----------------------------------------------------------------
; Implements a jump table to select various interrupt routines.
; Input:
;			BP - offset to the function table
;			AH - function number
; -----------------------------------------------------------------

INT_Dispatch:
			push bx
			mov bl, ah
			xor bh, bh
			shl bx, 1
			add bp, bx
			pop bx
			call [cs:bp]
			ret

INT_Unimplemented:
			ret

; -----------------------------------------------------------------
; INT 10 - screen functions.
; -----------------------------------------------------------------

INT_10:
			INT_Debug 10h
			cmp ah, 0Fh
			ja INT_10_Ret
			push bp
			push es
			mov bp, Data_Segment
			mov es, bp
			mov bp, INT_10_Functions
			call INT_Dispatch
			pop es
			pop bp

INT_10_Ret:
			iret

INT_10_Functions:
			dw INT_10_00
			dw INT_Unimplemented
			dw INT_10_02
			dw INT_10_03
			dw INT_Unimplemented
			dw INT_Unimplemented
			dw INT_10_06
			dw INT_10_07
			dw INT_Unimplemented
			dw INT_10_09
			dw INT_10_0A
			dw INT_Unimplemented
			dw INT_Unimplemented
			dw INT_Unimplemented
			dw INT_10_0E
			dw INT_10_0F
			
; -----------------------------------------------------------------
; INT 10 function 00 - set video mode.
; Outputs "clear screen" character.
; -----------------------------------------------------------------
			
INT_10_00:
			mov [es:Data_Boot], byte 00h
			
			; Make whole screen editable
			call IPC_WindowRemove

			; Output "clear screen" character
			mov al, CHAR_CLRSCR
			call IPC_ScreenOut
			
			; Cancel editing mode
			mov al, 'O'
			call IPC_ScreenEscape
			
			; Cancel screen reverse
			mov al, 'N'
			call IPC_ScreenEscape
			
			; Invalidate cursor position
			mov [es:Data_CursorPhysical], byte 0FFh
			
			ret

; -----------------------------------------------------------------
; INT 10 function 02 - set cursor position
; -----------------------------------------------------------------
			
INT_10_02:
			; MS BASIC Compiler runtime calls this function with DX=FFFF ?
			test dx, 8080h
			jnz INT_10_02_Ret

			; Check if row and column are within allowed bounds
			cmp dh, 24
			jl INT_10_02_RowOK
			mov dh, 23
INT_10_02_RowOK:
			cmp dl, 80
			jl INT_10_02_ColumnOK
			mov dl, 79
INT_10_02_ColumnOK:

			mov [es:Data_CursorVirtual], dx
			cmp dx, [es:Data_CursorPhysical]
			je INT_10_02_Ret
			
			mov [es:Data_CursorPhysical], dx
			call IPC_CursorSet

INT_10_02_Ret:
			ret

; -----------------------------------------------------------------
; INT 10 function 03 - get cursor position
; -----------------------------------------------------------------
			
INT_10_03:
			mov dx, [es:Data_CursorPhysical]
			cmp dl, 0FFh
			jne INT_10_03_OK
			call IPC_CursorGet
			mov [es:Data_CursorVirtual], dx
			mov [es:Data_CursorPhysical], dx
INT_10_03_OK:
			mov cx, 0C0Dh
			ret

; -----------------------------------------------------------------
; INT 10 function 06 - scroll screen up
; INT 10 function 07 - scroll screen down
; -----------------------------------------------------------------

INT_10_06:
INT_10_07:
			push ax
			call IPC_WindowSet
			pop ax
			
			; 0 lines = clear screen
			test al, al
			jz INT_10_06_Clear
			
			; Scroll direction
			cmp ah, 06h
			jnz INT_10_06_Down
			mov al, 'V'
			jmp INT_10_06_Scroll
INT_10_06_Down:
			mov al, 'W'
INT_10_06_Scroll:
			call IPC_ScreenEscape
			jmp IPC_WindowRemove

INT_10_06_Clear:
			mov al, CHAR_CLRSCR
			call IPC_ScreenOut
			jmp IPC_WindowRemove

; -----------------------------------------------------------------
; INT 10 function 09 - write character and attribute.
; -----------------------------------------------------------------

INT_10_09:
			call INT_ClearDot
			
			; MS BASIC Compiler runtime calls this function with AL=00 ?
			test al, al
			jz INT_10_09_Ret
			test cx, cx
			jz INT_10_09_Ret
			
			; Check if cursor position has not changed
			call INT_10_CursorCheck
			
			; Check if the attribute means "invert"
			push bx
			and bl, 77h
			xor bl, 07h
			cmp bl, 77h
			jne INT_10_09_NoReverse1
			push ax
			mov al, CHAR_RVSON
			call IPC_ScreenOut
			pop ax
INT_10_09_NoReverse1:
			
			; Output characters one by one
			push cx
			push ax
			xor ah, ah
INT_10_09_Loop:
			call IPC_ScreenOutPC
			loop INT_10_09_Loop
			pop ax
			pop cx
			
			; Cancel invert
			cmp bl, 77h
			jne INT_10_09_NoReverse2
			push ax
			mov al, CHAR_RVSOFF
			call IPC_ScreenOut
			pop ax
INT_10_09_NoReverse2:
			pop bx	
			
			call INT_10_CursorAdvance
			
INT_10_09_Ret:
			ret

; -----------------------------------------------------------------
; INT 10 function 0A - write character only.
; -----------------------------------------------------------------

INT_10_0A:
			push bx
			xor bl, bl
			call INT_10_09
			pop bx
			ret

; -----------------------------------------------------------------
; Checks if virtual and physical cursor positions match.
; -----------------------------------------------------------------

INT_10_CursorCheck:
			push dx

			cmp [es:Data_CursorPhysical], byte 0FFh
			je INT_10_CursorCheck_Dirty

			mov dx, [es:Data_CursorVirtual]
			cmp dx, [es:Data_CursorPhysical]
			je INT_10_CursorCheck_OK
			mov [es:Data_CursorPhysical], dx
			call IPC_CursorSet

INT_10_CursorCheck_OK:
			pop dx
			ret

INT_10_CursorCheck_Dirty:
			call IPC_CursorGet
			mov [es:Data_CursorVirtual], dx
			mov [es:Data_CursorPhysical], dx
			jmp INT_10_CursorCheck_OK

; -----------------------------------------------------------------
; Moves the virtual cursor position.
; Input:
;			CX - number of characters to move
; -----------------------------------------------------------------

INT_10_CursorAdvance:
			push dx
			mov dl, [es:Data_CursorPhysical]
			xor dh, dh
			add dx, cx

INT_10_CursorAdvance_0:
			cmp dx, 80
			jl INT_10_CursorAdvance_Ret
			inc byte [es:Data_CursorPhysical+1]
			sub dx, 80
			jmp INT_10_CursorAdvance_0
			
INT_10_CursorAdvance_Ret:
			mov [es:Data_CursorPhysical], dl
			pop dx
			ret
			
; -----------------------------------------------------------------
; INT 10 function 0E - teletype output.
; -----------------------------------------------------------------

INT_10_0E:
			call INT_ClearDot
			
			push ax

			; Check if cursor position has not changed
			cmp [es:Data_CursorPhysical], byte 0FFh
			je INT_10_0E_Dirty
			call INT_10_CursorCheck
INT_10_0E_Dirty:
			
			; Check control characters
			cmp al, 20h
			jl INT_10_0E_Control
INT_10_0E_Output:
			call IPC_ScreenOutPC
			
INT_10_0E_Finish:
			; Invalidate cursor position
			mov [es:Data_CursorPhysical], byte 0FFh

			pop ax
			ret
			
INT_10_0E_Output2:
			call IPC_ScreenOut
			jmp INT_10_0E_Finish

			; Translate common control codes
INT_10_0E_Control:
			cmp al, 7	; Bell
			jne INT_10_0E_Not07
			call IPC_ScreenOut
			pop ax
			ret
INT_10_0E_Not07:
			cmp al, 8	; BackSpace
			jne INT_10_0E_Not08
			mov al, CHAR_DEL
			jmp INT_10_0E_Output2
INT_10_0E_Not08:
			cmp al, 10	; LF
			jne INT_10_0E_Not0A
			mov al, CHAR_DOWN
			jmp INT_10_0E_Output2
INT_10_0E_Not0A:
			cmp al, 13	; CR
			jne INT_10_0E_Not0D
			mov al, 'J'
			call IPC_ScreenEscape
			jmp INT_10_0E_Finish
INT_10_0E_Not0D:
			jmp INT_10_0E_Output
			
; -----------------------------------------------------------------
; INT 10 function 0F - get video mode.
; -----------------------------------------------------------------

INT_10_0F:
			; MDA text mode
			mov al, 07h		
			mov ah, 80
			mov bh, 0
			ret

; -----------------------------------------------------------------
; INT 11 - equipment list.
; -----------------------------------------------------------------

INT_11:
			INT_Debug 11h
			
			; Detect 8087 processor
			call INT_11_CPU
			and ax, 0001h
			shl ax, 1

			; 2 disk drives, MDA card, 64K+ memory, 1 serial port
			add ax, 037Dh
			
			iret

; -----------------------------------------------------------------
; Equipment flags.
; -----------------------------------------------------------------

EQUIPMENT_8087      equ 1
EQUIPMENT_V20       equ 2

INT_11_CPU:
            push cx
            push bx
            ; Test if 8087 present
            fninit
            mov cx, 3
INT_11_CPU_8087:
            loop INT_11_CPU_8087
            mov bx, sp
            sub bx, 2
            mov [ss:bx], ax
            fnstcw [ss:bx]
            cmp [ss:bx], word 03FFh
            jne INT_11_CPU_No8087
            mov cl, EQUIPMENT_8087
INT_11_CPU_No8087:
            pop bx
            pop cx
            ret
            db 60h      ; PUSHA
            stc
            jnc INT_11_CPU_NoV20
            db 61h      ; POPA
            or cl, EQUIPMENT_V20
INT_11_CPU_NoV20:
            mov al, cl
            pop bx
            pop cx
            ret

; -----------------------------------------------------------------
; INT 12 - memory size.
; -----------------------------------------------------------------

INT_12:
			INT_Debug 12h
			push ds
			mov ax, Data_Segment
			mov ds, ax
			mov ax, [Data_MemSize]
			xchg al, ah
			shl ax, 1
			shl ax, 1
			pop ds
			iret


; -----------------------------------------------------------------
; INT 13 - disk functions.
; -----------------------------------------------------------------

INT_13:
			INT_Debug 13h
			cmp ah, 1Bh
			ja INT_13_Ret
			push bp
			mov bp, INT_13_Functions
			call INT_Dispatch
			pop bp
			retf 2
INT_13_Ret:
			iret

INT_13_Functions:
			dw INT_13_OK
			dw INT_13_01
			dw INT_13_02
			dw INT_13_03
			dw INT_13_OK
			dw INT_13_Error
			dw INT_13_Error
			dw INT_13_Error
			dw INT_13_08
			dw INT_13_Error
			dw INT_13_Error
			dw INT_13_Error
			dw INT_13_OK
			dw INT_13_OK
			dw INT_13_Error
			dw INT_13_Error
			dw INT_13_OK
			dw INT_13_Error
			dw INT_13_Error
			dw INT_13_Error
			dw INT_13_Error
			dw INT_13_15
			dw INT_13_16
			dw INT_13_Error
			dw INT_13_Error
			dw INT_13_Error
			dw INT_13_Error

; -----------------------------------------------------------------
; Check whether there is HD image in the ROM.
; -----------------------------------------------------------------

HD_Drive    equ 81h
SD_Drive    equ 80h

INT_13_HD:
%ifdef SD
			push ds
			push ax
			mov ax, Data_Segment
			mov ds, ax
			test byte [Data_SD], 01h
			pop ax
			pop ds
			jz INT_13_HD_2
            cmp dl, HD_Drive
            jne INT_13_HD_Do
            jmp SD_Handle
INT_13_HD_2:
            cmp dl, SD_Drive
            jne INT_13_HD_Do
            jmp SD_Handle
INT_13_HD_Do:
%endif
			push ds
			push ax
			mov ax, 0F000h
			mov ds, ax
			cmp [000Eh], word "HD"
			pop ax
			pop ds
			jz INT_13_HD_OK
			stc
			mov ah, 0FFh
			ret		
INT_13_HD_OK:
%ifdef SD
            cmp ah, 08h
            jne INT_13_HD_Not08
            call 0F000h:00008h
            mov dl, 02h
            ret
INT_13_HD_Not08:
%endif
            call 0F000h:00008h
            ret
            

; -----------------------------------------------------------------
; INT 13 function 00 - reset drive.
; -----------------------------------------------------------------

INT_13_OK:
			clc
			ret
			
INT_13_Error:
			stc
			mov al, 02h
			ret

; -----------------------------------------------------------------
; INT 13 function 01 - get status.
; -----------------------------------------------------------------

INT_13_01:
			clc
			xor al, al
			ret
			
; -----------------------------------------------------------------
; INT 13 function 02 - disk read.
; INT 13 function 03 - disk write.
; -----------------------------------------------------------------

INT_13_02:
			test dl, 80h
			jnz INT_13_HD
INT_13_02_Floppy:
			mov bp, 0
			jmp INT_13_Common
INT_13_03:
			test dl, 80h
			jnz INT_13_HD
			mov bp, 1
INT_13_Common:
			push es
			push cx
			push ax
			push ax
			
			call INT_13_Logical	

			pop cx
			xor ch, ch
INT_13_02_Loop:

			call INT_13_Disk
			jc INT_13_02_Error
			inc ax
			inc ch
			cmp ch, cl
			jne INT_13_02_Loop
INT_13_02_Break:
			mov al, ch
			xor ah, ah
			
INT_13_02_Ret:
			pop cx
			pop cx
			pop es
			ret

INT_13_02_Error:
			mov al, ch
			jmp INT_13_02_Ret

; -----------------------------------------------------------------
; Calculate logical sector number from PC geometry.
; Input:
;           CL - physical sector number
;           DH - physical head number
;           CH - physical track number
; Output:
;			AX - logical sector number
; -----------------------------------------------------------------

INT_13_Logical:
			push bx
			push ds
			mov ax, Data_Segment
			mov ds, ax
            mov al, ch
            xor ah, ah
            mov bl, [Data_NumHeads]
            mul bl
            add al, dh
            mov bl, [Data_TrackSize]
            mul bl
            mov bl, cl
            dec bl
            xor bh, bh
            add ax, bx
            pop ds
            pop bx
            ret

; -----------------------------------------------------------------
; Read or write PC sector
; Input:
;			BP - 0 for disk read, 1 for disk write
;			AX - 256-byte sector number
;			DL - drive number
;			ES:BX - buffer address
; -----------------------------------------------------------------

INT_13_Disk:
			push cx
			push ax
			
			; Convert 512- to 256-byte sectors
			push ds
			mov cx, Data_Segment
			mov ds, cx
			mov cl, [Data_SectorSize]
			xor ch, ch
			push dx
			mul cx
			pop dx
			pop ds
			
			; Check if read across 64 kB boundary
			push ax
			push bx
			mov ax, es
			shl ax, 1
			shl ax, 1
			shl ax, 1
			shl ax, 1
			add ax, bx
			test ax, ax
			jz INT_13_Disk_Zero
			xchg ax, bx
			mov ax, 1
			mul cl
			xchg al, ah
			add ax, bx
			jc INT_13_Disk_DMA_Error
			pop bx
			pop ax
			
			; Read physical sectors
INT_13_Disk_Loop:
			push ax
			call INT_BootDot
			call IPC_SectorCalc
			call IPC_SectorAccess
			cmp ax, 3030h
			jz INT_13_Disk_NoError
			pop ax
			pop ax
			pop cx
			stc
			mov ah, 2
			ret

INT_13_Disk_NoError:
			; Check if we were reading on the 0000 boundary
			; If yes, move the sector 2 bytes below and restore overwritten word
			test ch, 01h
			jz INT_13_NotZero
			push ds
			push si
			push di
			mov di, es
			mov ds, di
			sub bx, 2
			mov si, bx
			mov di, bx
			push cx
			mov cx, 128
			lodsw
			rep movsw
			pop cx
			xor ch, ch
			stosw
			pop di
			pop si
			pop ds
			
INT_13_NotZero:
			mov ax, es
			add ax, 16
			mov es, ax
			pop ax
			
			; If reading sector 0, set correct drive parameters
			test ax, ax
			jnz INT_13_Disk_NoTest
			call INT_13_ResetParams
INT_13_Disk_NoTest:
			inc ax
			loop INT_13_Disk_Loop
			pop ax
			pop cx
			clc
			ret

			; Fake "read across 64 boundary" error
INT_13_Disk_DMA_Error:
			pop bx
			pop ax
			pop ax
			pop cx
			stc
			mov ah, 9
			ret

			; Read on 0000-aligned address: move the pointer +2 bytes
INT_13_Disk_Zero:
			pop bx

			; Remember the word that will be overwritten
			mov ax, [es:bx+256]
			cmp bp, 1
			jne INT_13_Disk_NotWrite

			; If writing, move the sector 2 bytes up
			push ds
			push si
			push di
			mov si, es
			mov ds, si
			mov si, bx
			add si, 254
			mov di, bx
			add di, 256
			std
			push cx
			mov cx, 128
			rep movsw
			pop cx
			cld
			pop di
			pop si
			pop ds
INT_13_Disk_NotWrite:
			mov [es:bx], ax
			add bx, 2
			pop ax
			mov ch, 01h
			jmp INT_13_Disk_Loop
					
; -----------------------------------------------------------------
; Read parameters from MS-DOS boot sector
; -----------------------------------------------------------------
			
INT_13_ResetParams:
			push ds
			push ax
			mov ax, Data_Segment
			mov ds, ax
			
			; Test for boot sector - is the first byte a JMP?
			mov al, [es:bx-256+0]
			cmp al, 0E9h
			je INT_13_ResetParams_0
			cmp al, 0EBh
			jne INT_13_ResetParams_Default

			; Do the disk parameters make sense?
INT_13_ResetParams_0:
			mov al, [es:bx-256+0Ch]
			cmp al, 1
			je INT_13_ResetParams_1
			cmp al, 2
			jne INT_13_ResetParams_Default
INT_13_ResetParams_1:
			mov al, [es:bx-256+18h]
			cmp al, 8
			je INT_13_ResetParams_2
			cmp al, 9
			je INT_13_ResetParams_2
			cmp al, 15
			jne INT_13_ResetParams_Default
INT_13_ResetParams_2:
			mov al, [es:bx-256+1Ah]
			cmp al, 1
			je INT_13_ResetParams_OK
			cmp al, 2
			jne INT_13_ResetParams_Default
			
			; Parameters seem OK, copy them to the data section
INT_13_ResetParams_OK:
			mov al, [es:bx-256+0Ch]
			mov [Data_SectorSize], al
			mov al, [es:bx-256+18h]
			mov [Data_TrackSize], al
			mov al, [es:bx-256+1Ah]
			mov [Data_NumHeads], al
			pop ax
			pop ds
			ret
			
			; Reset disk parameters to default values
INT_13_ResetParams_Default:
			mov [Data_SectorSize], byte 2
			mov [Data_TrackSize], byte 9
			mov [Data_NumHeads], byte 2
			pop ax
			pop ds
			ret

; -----------------------------------------------------------------
; INT 13 function 08 - get drive parameters.
; -----------------------------------------------------------------

INT_13_08:
			test dl, 80h
			jz INT_13_08_Floppy
			jmp INT_13_HD
INT_13_08_Floppy:
			clc
			xor ah, ah
			mov bl, 03h
			mov cx, 5009h
			mov dx, 0102h
			mov di, INT_1E
			push cs
			pop es
			ret
			
; -----------------------------------------------------------------
; INT 13 function 15 - get disk change type.
; -----------------------------------------------------------------

INT_13_15:
			test dl, 80h
			jz INT_13_15_Floppy
			jmp INT_13_HD
INT_13_15_Floppy:
			clc
			mov ah, 01h
			ret

; -----------------------------------------------------------------
; INT 13 function 16 - get disk change flag.
; -----------------------------------------------------------------

INT_13_16:
			clc
			mov ah, 01h
			ret
            
; -----------------------------------------------------------------
; INT 14 - serial functions.
; -----------------------------------------------------------------

INT_14:
			INT_Debug 14h
			cmp ah, 03h
			ja INT_14_Ret
			push bp
			mov bp, INT_14_Functions
			call INT_Dispatch
			pop bp
INT_14_Ret:
			iret

INT_14_Functions:
			dw INT_14_00
			dw INT_14_01
			dw INT_14_02
			dw INT_14_03

; -----------------------------------------------------------------
; INT 14 function 00 - initialize serial port (unimplemented).
; -----------------------------------------------------------------
			
INT_14_00:
			ret

; -----------------------------------------------------------------
; INT 14 function 01 - send character.
; -----------------------------------------------------------------
			
INT_14_01:
			test dx, dx
			jnz INT_14_NoPort
			call IPC_SerialOut
			xor ah, ah
			ret
INT_14_NoPort:
			ret

; -----------------------------------------------------------------
; INT 14 function 02 - receive character.
; -----------------------------------------------------------------
			
INT_14_02:
			test dx, dx
			jnz INT_14_NoPort
			call IPC_SerialIn
			xor ah, ah
			ret

; -----------------------------------------------------------------
; INT 14 function 03 - get serial port status.
; -----------------------------------------------------------------
			
INT_14_03:
			test dx, dx
			jnz INT_14_NoPort
			mov ax, 6110h	
			ret

; -----------------------------------------------------------------
; INT 15 - BIOS functions.
; -----------------------------------------------------------------

INT_15:
			INT_Debug 15h
			stc
			retf 2

; -----------------------------------------------------------------
; INT 16 - keyboard functions.
; -----------------------------------------------------------------

INT_16:
			INT_Debug 16h
			cmp ah, 03h
			ja INT_16_Ret
			push bp
			mov bp, INT_16_Functions
			call INT_Dispatch
			pop bp
			retf 2 		; To retain the ZF flag!
INT_16_Ret:
			iret

INT_16_Functions:
			dw INT_16_00
			dw INT_16_01
			dw INT_16_02
			dw INT_Unimplemented

; -----------------------------------------------------------------
; INT 16 function 00 - read from keyboard buffer.
; -----------------------------------------------------------------

INT_16_00:
%ifdef SCREEN
			call Screen_Interrupt
%endif
			call IPC_KbdPeek
			jz INT_16_00
			call IPC_KbdClear
			call IPC_KbdConvert
			ret

; -----------------------------------------------------------------
; INT 16 function 01 - peek into keyboard buffer.
; -----------------------------------------------------------------

INT_16_01:
%ifdef SCREEN
			call Screen_Interrupt
%endif
			call IPC_KbdPeek
			jz INT_16_NoKey
			call IPC_KbdConvert
			ret
INT_16_NoKey:
			xor ax, ax
			ret

; -----------------------------------------------------------------
; INT 16 function 02 - get shift key state.
; -----------------------------------------------------------------

INT_16_02:
			call IPC_KbdPeek
			shr ah, 1
			shr ah, 1
			shr ah, 1
			shr ah, 1
			mov al, ah
			and ax, 0201h
			shl ah, 1
			or al, ah
			xor al, 05h
			ret

; -----------------------------------------------------------------
; INT 17 - printer functions.
; -----------------------------------------------------------------

INT_17:
			INT_Debug 17h
			cmp ah, 02h
			ja INT_17_Ret
			push bp
			mov bp, INT_17_Functions
			call INT_Dispatch
			pop bp
INT_17_Ret:
			iret

INT_17_Functions:
			dw INT_17_00
			dw INT_17_01
			dw INT_17_02

; -----------------------------------------------------------------
; INT 17 function 00 - output byte to printer.
; -----------------------------------------------------------------
			
INT_17_00:
			call IPC_PrinterOut
			ret

; -----------------------------------------------------------------
; INT 17 function 01 - initialize printer (unimplemented).
; -----------------------------------------------------------------
			
INT_17_01:
			ret

; -----------------------------------------------------------------
; INT 17 function 02 - get printer status.
; -----------------------------------------------------------------
			
INT_17_02:
			mov ah, 80h
			ret

; -----------------------------------------------------------------
; INT 18 - ROM BASIC.
; -----------------------------------------------------------------

INT_18:
			INT_Debug 18h
			jmp INT_19_Again

; -----------------------------------------------------------------
; INT 19 - Reboot.
; -----------------------------------------------------------------

INT_19:
			INT_Debug 19h
INT_19_Again:
%ifndef SCREEN
			call Init_Data
%endif

%ifdef BIG
			mov si, INT_19_Banner1
			call Output_String
INT_19_Loop:
            call INT_16_00
			cmp ah, 3Ch ; F2
			jz INT_19_Floppy
			cmp ah, 3Dh ; F3
			jnz INT_19_Loop2
			push ds
			push ax
			mov ax, Data_Segment
			mov ds, ax
			mov byte [Data_SD], 01h
			pop ax
			pop ds
			jmp INT_19_HD
INT_19_Loop2:
			cmp ah, 3Bh ; F1
			jnz INT_19_Loop
            
			; Try loading boot sector from hard disk
INT_19_HD:
			mov dx, 0080h
			mov ax, 0201h
			xor cx, cx
			mov es, cx
			inc cx
			mov bx, 7C00h
			call INT_13_02
			jc INT_19_Error
			cmp [es:7DFEh], word 0AA55h
			jne INT_19_NoSystem
			mov dl, 80h
			jmp INT_19_Found
%endif
						
INT_19_Floppy:
			; Load two first 256-byte sectors from the floppy disk.
			xor bx, bx
			mov es, bx
			mov bp, bx
			mov bx, 7C00h
			xor dl, dl
			mov ax, 0001h
			call IPC_SectorAccess
			mov bx, 7D00h
			call INT_13_ResetParams
			mov ax, 0101h
			call IPC_SectorAccess
			cmp [es:7DFEh], word 0AA55h
			jne INT_19_NoSystem
			xor dl, dl

INT_19_Found:
			push dx

%ifndef STANDALONE
			mov bx, 0040h
			call IPC_Install
%endif
			; At this point there is no return to underlying OS.
			; It is safe to relocate the INT 07 vector and IRQs.
			call IPC_Init
		
			; Jump to boot sector code.
			call INT_19_Segments
			mov si, INT_19_Banner2
			call Output_String
			mov [es:Data_Boot], byte 80h
			pop dx
			jmp 0000:7C00h
			
INT_19_NoSystem:
			call INT_19_Segments
			mov si, INT_19_Banner3
			call Output_String
			jmp INT_19_Again

INT_19_Segments:
			mov ax, Data_Segment
			mov es, ax
			push cs
			pop ds
			ret
			
%ifdef BIG

INT_19_Error:
			call INT_19_Segments
			mov si, INT_19_Banner4
			call Output_String
			jmp INT_19_Again

INT_19_Banner1:
			db "Select your boot device:", 10, 13
			db " F1 - SD card", 10, 13
			db " F2 - Floppy disk", 10, 13
			db " F3 - EPROM disk", 10, 13 
			db 0
INT_19_Banner4:
			db "SD card not found, please try again.", 10, 13, 0		

%endif

INT_19_Banner2:
			db "The system is coming up, please wait.", 10, 13, 0		

INT_19_Banner3:
			db "Insert a system disk and press any key.", 10, 13, 0		

; -----------------------------------------------------------------
; Dots printed on disk access when the system boots.
; -----------------------------------------------------------------

INT_BootDot:			
            call IPC_ShowProgress
			ret

INT_ClearDot:
			ret
			
; -----------------------------------------------------------------
; INT 1A - Timer functions.
; -----------------------------------------------------------------

INT_1A:
			INT_Debug 1Ah
			test ah, ah
			je INT_1A_00
			cmp ah, 01
			je INT_1A_01
			stc
			xor dx, dx
			xor cx, cx
			retf 2
			
; -----------------------------------------------------------------
; INT 1A function 00 - get system time.
; -----------------------------------------------------------------

INT_1A_00:
			push ax
			push bx
			call IPC_TimeGet
			
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
			
			pop bx
			pop ax
			xor al, al
			xchg cx, dx
			iret

; -----------------------------------------------------------------
; INT 1A function 01 - set system time.
; -----------------------------------------------------------------

INT_1A_01:
			push ax
			push bx
			push cx
			push dx
			mov ax, dx
			mov dx, cx
			
			; Calculate hour and minute
			mov cx, 1092 ; Ticks per minute
			div cx
			mov bx, dx
			mov cl, 60
			div cl
			xchg al, ah
			
			; Calculate number of seconds
			xchg ax, bx
			xor dx, dx
			mov cx, 50
			mul cx
			mov cx, 91
			div cx
			mov cl, 10
			div cl
			xchg al, ah
			
			mov dx, bx			
			call IPC_TimeSet
			
			pop dx
			pop cx
			pop bx
			pop ax
			iret

; -----------------------------------------------------------------
; INT 1B - Ctrl+Break.
; -----------------------------------------------------------------

INT_1B:
			INT_Debug 1Bh
			iret
			
; -----------------------------------------------------------------
; INT 1C - System tick.
; -----------------------------------------------------------------

INT_1C:
;			INT_Debug 1Ch
			iret
			
; -----------------------------------------------------------------
; INT 1E - disk parameter table.
; -----------------------------------------------------------------

INT_1E:
			db 0DFh
			db 02h
			db 25h
			db 02h
			db 09h
			db 2Ah
			db 0FFh
			db 50h
			db 0F6h
			db 0Fh
			db 02h
			db 00h

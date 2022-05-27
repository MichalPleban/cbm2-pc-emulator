

CHAR_CLRSCR	equ 147

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
; INT 10 - screen functions moved to screen.asm
; -----------------------------------------------------------------



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
			mov ax, (MemTop-40h)/64
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


INT_13_HD:
            cmp dl, 080h
            jne INT_13_HD_1
            jmp SD_Handle
INT_13_HD_1:
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
            mov bl, 2
            mul bl
            add al, dh
            mov bl, 9
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
			mov cl, 2
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
            call IPC_SerialStatus
            cmp al, 00h
			mov ax, 6010h
			jz INT_14_03_NoData
			or ah, 01h
INT_14_03_NoData:
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
			and ah, 0CFh    ; Map 1x and 2x functions to 0x
			cmp ah, 09h
			je INT_16_09
			cmp ah, 03h
			ja INT_16_Ret
			push bp
			mov bp, INT_16_Functions
			call INT_Dispatch
			pop bp
			retf 2 		    ; To retain the ZF flag!
INT_16_09:
			xor al, al
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
			call Screen_Interrupt
            out 0E8h, al
            in al, 21h
            out 0E9h, al
            test al, 01h
            jnz INT_16_00
			push ax
			mov ah, al
			call INT_16_BIOSFlags
			pop ax
			call IPC_KbdClear
			call IPC_KbdConvert
            push ds
			push ax
			mov ax, Data_Segment
			mov ds, ax
			test [Data_Boot], byte 80h
			jz INT_16_00_NoBoot
			int 09h
INT_16_00_NoBoot:
			pop ax
			pop ds
INT_16_00_Ret:
			ret

; -----------------------------------------------------------------
; INT 16 function 01 - peek into keyboard buffer.
; -----------------------------------------------------------------

INT_16_01:
			call Screen_Interrupt
            out 0E8h, al
            in al, 21h
            out 0E9h, al
			push ax
			mov ah, al
			call INT_16_BIOSFlags
			pop ax
            test al, 01h
            jnz INT_16_NoKey            
			call IPC_KbdPeek
			jmp IPC_KbdConvert
INT_16_NoKey:
			xor ax, ax
			ret

; -----------------------------------------------------------------
; INT 16 function 02 - get shift key state.
; -----------------------------------------------------------------

INT_16_02:
            out 0E8h, al
            in al, 21h
            out 0E9h, al
            mov ah, al

			; Store shift key state in BIOS data area for Turbo Pascal 7
INT_16_BIOSFlags:
            xor al, al
            test ah, 10h
            jnz INT_16_BIOSFlags_NoShift
            or al, 01h
INT_16_BIOSFlags_NoShift:
            test ah, 20h
            jnz INT_16_BIOSFlags_NoCtrl
            or al, 04h
INT_16_BIOSFlags_NoCtrl:
            test ah, 08h
            jnz INT_16_BIOSFlags_NoAlt
            or al, 08h
INT_16_BIOSFlags_NoAlt:
			push bx
			push ds
			xor bx, bx
			mov ds, bx
			mov [0417h], al
			pop ds
			pop bx
			mov ah, 02h
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
            push cs
            pop ds
            call Output_Line
			mov si, INT_19_Banner1
			call Output_String
INT_19_Loop:
            call INT_16_00
			cmp ah, 3Ch ; F2
			jz INT_19_Floppy
			cmp ah, 3Bh ; F1
			jz INT_19_HD
			cmp ah, 44h ; F10
			jz Config_Modify
			cmp ax, 02E03h ; Run/Stop
			jz Config_Reset
			jmp INT_19_Loop
            
			; Try loading boot sector from hard disk
INT_19_HD:
            call Output_Line
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
						
INT_19_Floppy:
            call Output_Line
			; Load two first 256-byte sectors from the floppy disk.
			xor bx, bx
			mov es, bx
			mov bp, bx
			mov bx, 7C00h
			xor dl, dl
			mov ax, 0001h
			call IPC_SectorAccess
			mov bx, 7D00h
			mov ax, 0101h
			call IPC_SectorAccess
			cmp [es:7DFEh], word 0AA55h
			jne INT_19_NoSystem
			xor dl, dl

INT_19_Found:
			push dx

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
			
INT_19_Error:
			call INT_19_Segments
			mov si, INT_19_Banner4
			call Output_String
			jmp INT_19_Again

INT_19_Banner1:
			db "Select an option:", 10, 13
			db " F1       - Boot from SD card", 10, 13
			db " F2       - Boot from floppy disk", 10, 13
			db " F10      - Modify configuration", 10, 13
			db " Run/Stop - Reset configuration", 10, 13
			db 0
INT_19_Banner4:
			db "SD card not found, please try again.", 10, 13, 0		

INT_19_Banner2:
			db "The system is coming up, please wait.", 10, 13, 0		

INT_19_Banner3:
			db "Insert a system disk and press any key.", 10, 13, 0		

			
; -----------------------------------------------------------------
; INT 1A - Timer functions.
; -----------------------------------------------------------------

INT_1A:
			INT_Debug 1Ah
			test ah, ah
			je INT_1A_00
			cmp ah, 01
			je INT_1A_01
			cmp ah, 02
			je INT_1A_02
			cmp ah, 03
			je INT_1A_03
			cmp ah, 04
			je INT_1A_04
			cmp ah, 05
			je INT_1A_05
			stc
			xor dx, dx
			xor cx, cx
			retf 2
			
; -----------------------------------------------------------------
; INT 1A function 00 - get system time.
; -----------------------------------------------------------------

INT_1A_00:
            push ds
            xor cx, cx
            mov ds, cx
            mov dx, [046Ch]
            mov cx, [046Eh]
            xor al, al
            pop ds
            clc
            retf 2
            
;			push ax
;			push bx

;            call INT_1A_02_Do
;            mov al, dh
;            call ConvertFromBCD
;            mov ah, al          ; AH = Seconds
;            push ax
;			mov al, cl
;			call ConvertFromBCD
;			mov dl, al          ; DL = Minutes
;			mov al, ch
;			call ConvertFromBCD
;			mov dh, al          ; DH = Hours
;			pop ax
;			xor al, al          ; AL = Microseconds

			; Calculate number of ticks in whole minutes
;			mov bx, ax
;			mov al, dh
;			mov cl, 60
;			mul cl
;			xor dh, dh
;			add ax, dx
;			mov cx, 1092 ; Ticks per minute
;			mul cx
;			push dx
;			push ax
			
			; Calculate number of ticks in seconds
;			mov al, bh
;			mov cl, 10
;			mul cl
;			xor bh, bh
;			add ax, bx
;			mov cx, 182
;			mul cx
;			mov cx, 100
;			div cx
			
			; Add them together
;			pop cx
;			add cx, ax
;			pop dx
;			xor ax, ax
;			adc dx, ax
			
;			pop bx
;			pop ax
;			xor al, al
;			xchg cx, dx
;			iret

; -----------------------------------------------------------------
; INT 1A function 01 - set system time.
; -----------------------------------------------------------------

INT_1A_01:
			push ax
            push ds
            xor ax, ax
            mov ds, ax
            mov [046Ch], dx
            mov [046Eh], cx
            pop ds
            pop ax
            clc
            retf 2
            
;			push ax
;			push bx
;			push cx
;			push dx
;			mov ax, dx
;			mov dx, cx
			
			; Calculate hour and minute
;			mov cx, 1092 ; Ticks per minute
;			div cx
;			mov bx, dx
;			mov cl, 60
;			div cl
;			xchg al, ah
			
			; Calculate number of seconds
;			xchg ax, bx
;			xor dx, dx
;			mov cx, 50
;			mul cx
;			mov cx, 91
;			div cx
;			mov cl, 10
;			div cl
;			xchg al, ah
			
;			mov dx, bx
;			push ax

;            mov al, dh
;            call ConvertToBCD
;            mov ch, al
;            mov al, dl
;            call ConvertToBCD
;            mov cl, al
;			pop ax
;            mov al, ah
;            call ConvertToBCD
;            mov dh, al
;            call INT_1A_03_Do
			
;			pop dx
;			pop cx
;			pop bx
;			pop ax
;			iret

; -----------------------------------------------------------------
; INT 1A function 02 - get RTC time.
; -----------------------------------------------------------------

INT_1A_02:
            call INT_1A_02_Do
            retf 2

INT_1A_02_Do:
            push ax
            call I2C_Start
            
            ; RTC adress + write flag
            mov al, 0D0h
            call I2C_Send
            jnc INT_1A_02_Do2
            call I2C_Stop
            pop ax
            stc
            ret

INT_1A_02_Do2:
            ; Read start address
            mov al, 00h
            call I2C_Send
            
            call I2C_Start

            ; RTC adress + read flag
            mov al, 0D1h
            call I2C_Send
            
            ; Read address 00 (seconds)
            clc
            call I2C_Receive
            and al, 7Fh
            mov dh, al

            ; Read address 01 (minutes)
            clc
            call I2C_Receive
            mov cl, al

            ; Read address 02 (seconds)
            stc
            call I2C_Receive
            mov ch, al
            xor dl, dl

            call I2C_Stop
            pop ax
            clc
            ret

; -----------------------------------------------------------------
; INT 1A function 03 - set RTC time.
; -----------------------------------------------------------------

INT_1A_03:
            call INT_1A_03_Do
            retf 2
            
INT_1A_03_Do:
            push ax
            call I2C_Start
            
            ; RTC adress + write flag
            mov al, 0D0h
            call I2C_Send
            jnc INT_1A_03_Do2
            call I2C_Stop
            pop ax
            stc
            ret

INT_1A_03_Do2:
            
            ; Write start address
            mov al, 00h
            call I2C_Send
                        
            ; Write address 00 (seconds)
            mov al, dh
            call I2C_Send

            ; Write address 01 (minutes)
            mov al, cl
            call I2C_Send

            ; Write address 02 (seconds)
            mov al, ch
            call I2C_Send

            call I2C_Stop
            pop ax
            clc
            ret

INT_1A_NoRTC:
            call I2C_Stop
            pop ax
            stc
            iret

; -----------------------------------------------------------------
; INT 1A function 04 - get RTC date.
; -----------------------------------------------------------------

INT_1A_04:
            push ax
            call I2C_Start
            
            ; RTC adress + write flag
            mov al, 0D0h
            call I2C_Send
            jc INT_1A_NoRTC
            
            ; Read start address
            mov al, 04h
            call I2C_Send
            
            call I2C_Start

            ; RTC adress + read flag
            mov al, 0D1h
            call I2C_Send
            
            ; Read address 04 (day)
            clc
            call I2C_Receive
            mov dl, al

            ; Read address 05 (month)
            clc
            call I2C_Receive
            mov dh, al

            ; Read address 06 (year)
            stc
            call I2C_Receive
            mov cl, al
            mov ch, 020h

            call I2C_Stop
            pop ax
            clc
            retf 2

; -----------------------------------------------------------------
; INT 1A function 05 - set RTC date.
; -----------------------------------------------------------------

INT_1A_05:
            push ax
            call I2C_Start
            
            ; RTC adress + write flag
            mov al, 0D0h
            call I2C_Send
            jc INT_1A_NoRTC
            
            ; Write start address
            mov al, 04h
            call I2C_Send
            
            ; Write address 04 (day)
            mov al, dl
            call I2C_Send

            ; Write address 05 (month)
            mov al, dh
            call I2C_Send

            ; Write address 06 (year)
            mov al, cl
            call I2C_Send

            call I2C_Stop
            pop ax
            clc
            retf 2


; -----------------------------------------------------------------
; Convert BCD to decimal
; -----------------------------------------------------------------

ConvertFromBCD:
            mov bh, al
            and bh, 0Fh
            shr al, 1
            shr al, 1
            shr al, 1
            shr al, 1
            mov bl, 10
            mul bl
            add al, bh
            ret

; -----------------------------------------------------------------
; Convert decimal to BCD
; -----------------------------------------------------------------

ConvertToBCD:
            aam
            shl ah, 1
            shl ah, 1
            shl ah, 1
            shl ah, 1
            or al, ah
            ret

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

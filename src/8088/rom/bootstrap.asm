

; -----------------------------------------------------------------
; Start the ROM code
; -----------------------------------------------------------------

Bootstrap:
            push cs
            pop ds
            in al, 0E4h
            or al, 060h
            out 0E4h, al
            
            ; Copy the upper ROM to RAM
            call Bootstrap_Copy
            
            ; Install IPC routines
            call Bootstrap_Init
            mov si, Bootstrap_String_Init
            call Bootstrap_String
            
            ; Check & load RAM configuration
            call Config_Read
            call Config_CRC
            jz Bootstrap1
            mov si, Bootstrap_String_Corrupted
            call Bootstrap_String
            call Config_Zero
            call Config_Write
Bootstrap1:

            ; Copy the payload to RAM
            call Bootstrap_Load
            
            ; Load the 6509 code
            mov si, Bootstrap_String_Boot
            call Bootstrap_String
            call Bootstrap_IPC22
            
            in al, 0E4h
            and al, 09Fh
            out 0E4h, al
         
    		jmp	RomInit


; -----------------------------------------------------------------
; Initialize IPC vectors for calling the 6509 stub
; -----------------------------------------------------------------

Bootstrap_Init:
            ; Segment for the IPC table
            mov bx, MemTop-10h
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
			mov cx, MemTop-10h
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
			mov cx, MemTop-10h
			mov ds, cx
			mov ax, [0090h]
			mov [000Ah+2], ax
			mov ax, [0092h]
			mov [000Ah+4], ax
			mov ax, [0094h]
			mov [000Ah+6], ax
			mov [000Ah+7], byte 0
			pushf
			sti
			mov cl, 0A2h
			call 0F000h:0F003h
			popf
			pop ds
			pop cx
			ret

; -----------------------------------------------------------------
; String output via IPC
; Input:
;           SI - adress of null-terminated string
; -----------------------------------------------------------------

Bootstrap_String:
            push cs
            pop ds
Bootstrap_String1:
            lodsb
            test al, al
            jz Bootstrap_String2
            call Bootstrap_IPC12
            jmp Bootstrap_String
Bootstrap_String2:
            ret


; -----------------------------------------------------------------
; Copy the upper ROM code (from F000:F000) to RAM
; -----------------------------------------------------------------

Bootstrap_Copy:
            mov ax, cs
            mov ds, ax
            mov es, ax
            mov si, RomStart
            mov di, si
            mov cx, RomEnd-RomStart
            rep movsb
            ret

; -----------------------------------------------------------------
; Copy the payload from ROM to RAM
; -----------------------------------------------------------------

Bootstrap_Load:

%ifdef DEVEL
            ; Development ROM: check if there is already code in RAM
            in al, 0E4h
            and al, 0DFh
            out 0E4h, al
            cmp byte [cs:0000h], 0EAh
            jnz Bootstrap_Load_1
            cmp word [cs:0001h], 0F000h
            jnz Bootstrap_Load_1
            cmp word [cs:0003h], 0F000h
            jnz Bootstrap_Load_1
            mov si, Bootstrap_String_LoadRAM
            call Bootstrap_String
            ret

Bootstrap_Load_1:
            in al, 0E4h
            or al, 020h
            out 0E4h, al
%endif
            call EEPROM_Setup
            cmp dl, 0EAh
            jne Bootstrap_Load_2
            mov si, Bootstrap_String_LoadEEPROM
            call Bootstrap_String
            call EEPROM_Read
            mov al, 13
            call Bootstrap_IPC12
            ret
Bootstrap_Load_2:
            mov ax, cs
            mov ds, ax
            mov es, ax
            mov si, Bootstrap_String_LoadROM
            call Bootstrap_String
            xor ax, ax
            mov si, ax
            mov di, ax
            mov cx, PayloadEnd
            rep movsb
            ret
            
; -----------------------------------------------------------------
; Initialize EEPROM read
; -----------------------------------------------------------------

EEPROM_Setup:
            mov ax, 0F000h
            mov es, ax
            xor ax, ax
            mov di, ax
            call I2C_Start
            mov al, 0A0h
            call I2C_Send
            xor al, al
            call I2C_Send
            xor al, al
            call I2C_Send
            call I2C_Start
            mov al, 0A1h
            call I2C_Send
            clc
            call I2C_Receive
            mov dl, al
            mov cx, 7
EEPROM_Setup1:
            clc
            call I2C_Receive
            loop EEPROM_Setup1
            clc
            call I2C_Receive
            mov bl, al
            clc
            call I2C_Receive
            mov bh, al
            call I2C_Stop
            ret

; -----------------------------------------------------------------
; Read data from EEPROM
; -----------------------------------------------------------------

EEPROM_Read:
            call I2C_Start
            mov al, 0A0h
            call I2C_Send
            xor al, al
            call I2C_Send
            xor al, al
            call I2C_Send
            call I2C_Start
            mov al, 0A1h
            call I2C_Send
EEPROM_Read0:
            cli
            cmp di, bx
            jbe EEPROM_Read1
            call I2C_Stop
            sti
            ret
EEPROM_Read1:
            mov cx, 128
EEPROM_Read2:
            clc
            call I2C_Receive
            stosb
            loop EEPROM_Read2
            mov al, '.'
            call Bootstrap_IPC12
            jmp EEPROM_Read0

; -----------------------------------------------------------------
; Strings to be output
; -----------------------------------------------------------------

Bootstrap_String_Init:
            db CHAR_CLRSCR, "8088 boostrapper v1.10 (C) 2019 Michal Pleban", 13, 0

Bootstrap_String_LoadROM:
            db "Loading the payload from ROM...", 13, 0
            
Bootstrap_String_LoadEEPROM:
            db "Loading the payload from EEPROM...", 13, 0
            
%ifdef DEVEL
Bootstrap_String_LoadRAM:
            db "Payload already found in RAM.", 13, 0
%endif
            
Bootstrap_String_Boot:
            db "Loading the 6509 code...", 13, 0

Bootstrap_String_Corrupted:
            db "Initializing configuration data...", 13, 0

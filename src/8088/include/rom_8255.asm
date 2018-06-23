
cia_pra   equ 40h
cia_prb   equ 40h
cia_prc   equ 40h
cia_ddra   equ 40h

;-----------------------------------------------------------------------------
;     8255 ports
;-----------------------------------------------------------------------------
ppi_porta	equ 20h			; port register A (inputs)
ppi_portb	equ 21h			; port register B (data)
ppi_portc	equ 22h			; port register C (outputs)
ppi_ctrl	equ 23h			; control register

data_in     equ 92h         ; Input data from 6509
data_out    equ 90h         ; Output data to 6509

pbbus1		equ 01h			; porta_0
pbbus2		equ 02h			; porta_1
pbsem65		equ 08h			; porta_3

bit_sem88   equ 6           ; PC6 (was PB2)
bit_int     equ 1           ; PC1 (was PB6)
bit_bus     equ 5           ; PC5 (was PC5)


;-----------------------------------------------------------------------------
;     8259A ports
;-----------------------------------------------------------------------------

inta00		equ 00h
inta01		equ 01h


;-----------------------------------------------------------------------------
;     RAM data definitions
;-----------------------------------------------------------------------------

start_code	equ 0
warm		equ 8
warmh		equ 9
ipcbufr		equ 0Ah
ipctab		equ 01Ah
int7		equ 7
int7seg		equ 1Eh

;-----------------------------------------------------------------------------
;  Macros to operate on data bits
;-----------------------------------------------------------------------------

;  Test semaphore from the 6509
%macro	SEM_TEST 0
		in al, ppi_porta
		test al, pbsem65
%endmacro

;  Raise the semaphore for the 6509
%macro	SEM_RAISE 0
		mov al, bit_sem88*2 + 1
		out ppi_ctrl, al
		nop
%endmacro

;  Clear the semaphore for the 6509
%macro	SEM_CLEAR 0
		mov al, bit_sem88*2 + 0
		out ppi_ctrl, al
		nop
%endmacro

;  Raise the interrupt pin for the 6526
;  This causes IRQ due to rising edge on the FLAG pin
%macro	INT_RAISE 0
		mov al, bit_int*2 + 1
		out ppi_ctrl, al
%endmacro

;  Clear the interrupt pin for the 6526
%macro	INT_CLEAR 0
		mov al, bit_int*2 + 0
		out ppi_ctrl, al
%endmacro

;  Raise the bus release pin
%macro	BUS_RAISE 0
		lock mov al, bit_bus*2 + 1
		lock out ppi_ctrl, al
%endmacro

;  Clear the bus release pin
%macro	BUS_CLEAR 0
		lock mov al, bit_bus*2 + 0
		lock out ppi_ctrl, al
%endmacro

;  Free the memory bus by toggling the BUSY pin
%macro  FREE_BUS 0
        lock nop
        BUS_RAISE
        lock nop
        lock nop
        lock nop
        BUS_CLEAR
        lock nop
%endmacro

;  Cause the interrupt on the 6509
%macro  INTERRUPT 0
        INT_RAISE
        times 10 nop
        INT_CLEAR
%endmacro

; Set the data port direction = output
%macro  DIRECTION_OUT 0
        mov	al, data_out
		out	ppi_ctrl, al
%endmacro

; Set the data port direction = input
%macro  DIRECTION_IN 0
        mov	al, data_in
		out	ppi_ctrl, al
%endmacro

;  Read data from the 6509
%macro  DATA_READ 0
		in	al, ppi_portb
%endmacro

;  Write data to the 6509
%macro  DATA_WRITE 0
		out	ppi_portb, al
%endmacro

;-----------------------------------------------------------------------------
;  Continue servicing request from the 6509
;-----------------------------------------------------------------------------

		jmp	rqst900

;-----------------------------------------------------------------------------
;  Issue IRQ request to 6509
;
;   enter:  CL = command byte
;           IpcBufr = holds input param bytes
;
;   exit:   IpcBufr = holds output param bytes
;-----------------------------------------------------------------------------
rqster:
		push ax
		push bx
		push cx
		push dx
		push si
		push es
		push ds

		mov	ax, 0
		mov	ds, ax		    ; set up DS to interrupt area

		mov	ax, [int7seg]	; get segment of ipctab from int 7 vector
		mov	ds, ax

		mov	al, cl		    ; set dl-#bytes to send
		and	al, 7Fh		    ;     dh-#bytes to receive
		mov	bl, 6
		mul	bl		        ; ax = reg * al
		mov	si, ax
		mov	dx, [si+1Ah]

rqst000:
;
;   Initiate IRQ to 6509, sending CMD byte
;
        SEM_TEST
		jnz	rqst000		
		
        SEM_RAISE        

        SEM_TEST
		jz rqst010

        SEM_CLEAR

		jmp	short rqst000	;  and try again....

rqst010:
        DIRECTION_OUT

		mov	al, cl
		DATA_WRITE

        INTERRUPT

rqst030:
        SEM_TEST
		jz rqst030

        DIRECTION_IN
		
		mov	si, 0
		inc	dl
		jmp	short rqst120
		
;
;  Send parameter bytes to 6509
;
rqst100:
        DIRECTION_OUT

		mov	al, [ipcbufr+si]
		DATA_WRITE

        SEM_RAISE        

rqst110:
        SEM_TEST
		jz rqst110

		DIRECTION_IN

		inc	si
rqst120:
		dec	dl		    ; decrease count, more to send?
		jz rqst200		; no, -> ready

        SEM_CLEAR

rqst130:
        SEM_TEST
		jnz	rqst130

		jmp	rqst100	    ; and repeat...
		
rqst200:
		test cl, 80h	; need to give up data bus?
		jz rqst210	    ; no, ->
		
		FREE_BUS
        SEM_CLEAR

		hlt

;
;  Receive data bytes from 6509
;
rqst210:
        SEM_CLEAR		

rqst220:
        SEM_TEST
		jnz	rqst220		; no, -> wait

		mov	si, 0
		inc	dh
		jmp	short rqst350
		
rqst310:
        SEM_RAISE        

rqst320:
        SEM_TEST
		jz rqst320

		DATA_READ
		mov	[ipcbufr+si],al
		
        SEM_CLEAR

rqst330:
        SEM_TEST
		jnz	rqst330
		
		inc	si
rqst350:
		dec	dh		; decrease count, more?
		jnz	rqst310		; yes, ->
rqst400:
		pop	ds
		pop	es
		pop	si
		pop	dx
		pop	cx
		pop	bx
		pop	ax
		retf			; Return far

rqst900:
		pop	dx
		pop	dx
		pop	dx

        SEM_CLEAR

		pop	si
		pop	ds
		pop	es
		pop	dx
		pop	cx
		pop	bx
		pop	ax
		pop	ax		    ; pop unneeded IRQ return
		pop	ax
		popf			; Pop flags

		jmp	short rqst400

;-----------------------------------------------------------------------------
;  Service an IRQ from the 6509
;-----------------------------------------------------------------------------
server:
		push ax
		push bx
		push cx
		push dx
		push es
		push ds
		push si

		mov	ax, 0
		mov	ds, ax		    ; set up DS to interrupt area

		mov	ax, [int7seg]	; get segment of ipctab from int 7 vector
		mov	ds, ax

;
;   Decode the command
;
		DATA_READ
		and	al, 7Fh
		mov	bl, 6		    ; calculate entry to index
		mul	bl		        ; ax = reg * al
		mov	si, ax		    ; get jump address, param counts

		mov	cx, [ipctab+2+si]	; CX := jump address offset
		mov	[start_code+4], cx	; move offset to RAM jump vector
		mov	cx, [ipctab+4+si]	; CX := jump address segment
		mov	[start_code+6], cx	; move segment to RAM jump vector
		mov	dx, [ipctab+si]		; dl = # ins, dh = # outs

        SEM_RAISE        

rqst050:
        SEM_TEST
		jnz	rqst050

		mov	si,0
		inc	dl
		jmp	short serv130

;
;  Get input parameter bytes
;
serv100:
        SEM_CLEAR

serv110:
        SEM_TEST
		jz serv110

		DATA_READ
		mov	[ipcbufr+si],al	;  and store it

        SEM_RAISE        
        
serv120:
        SEM_TEST
		jnz	serv120

		inc	si
serv130:
		dec	dl		; decrease count, more?
		jnz	serv100		; yes, ->

;
;   Process command
;
		push dx
		push cs

		mov dx, serv220
;		mov	dl, low  offset serv220
;		mov	dl,61h
;		mov	dh, high offset serv220
;		mov	dh,0F1h

		push dx		; push return on stack
		int	7		; gone!

serv220:
		pop	dx		; restore dh
		cmp	dh,0
		je	serv400			; Jump if equal
		
		mov	si,0

;
;   Send return parameter bytes
;
serv300:
        SEM_CLEAR

serv310:
        SEM_TEST
		jz serv310

		DIRECTION_OUT

		mov	al,[si+0Ah]
		DATA_WRITE

        SEM_RAISE        

serv320:
        SEM_TEST
		jnz	serv320

        DIRECTION_IN

		inc	si

		dec	dh		    ; decrease count, more?
		jnz	serv300		; yes, ->
serv400:
		cli			    ; Disable interrupts

        SEM_CLEAR

		pop	si
		pop	ds
		pop	es
		pop	dx
		pop	cx
		pop	bx
		pop	ax

		iret			; Interrupt return
		retn

;----------------------------------------------------------------------------
;  startup:  do initialization
;----------------------------------------------------------------------------
startf:
		cli			; Disable interrupts

		mov	sp, 0F000h

;
;  8255 initialization
;
        DIRECTION_IN
;
;  Release the memory bus for the 6509
;
		FREE_BUS
		
;
;  8259A initialization
;
		mov	al, 1Bh		    ; icw1:level, single, icw4
		out	inta00, al

		mov	al, 8		    ; icw2: interrupt address
		out	inta01,al

		mov	al, 1		    ; icw4: 8086 mode
		out	inta01, al

		mov	al, 0FEh		; ocw: inhibit I7-I1
		out	inta01, al

		sti			        ; Enable interrupts

		hlt
		
		times 0F1E2h-($-$$) db 0FFh

;----------------------------------------------------------------------------
;  6509 - gen'd IRQ handler
;             cold IRQ => do cold start
;             warm IRQ => do server, return to requester code.
;----------------------------------------------------------------------------
intrpt:
		push ax
		push ds

		xor	ax, ax
		mov	ds, ax

		mov	ax, [int7seg]
		mov	ds, ax

		mov	al, 20h
		out	0, al		; EOI to 8259A

		in al, ppi_porta	
		test al, pbbus1		; 6509 off bus?
		jz quit		; no, ->

		in al, ppi_porta	
		test al, pbbus2
		jz nstart		; yes, ->
quit:
		pop	ds
		pop	ax
		pop	ax
		pop	ax
		pop	ax

		sti			; Enable interrupts

		FREE_BUS
        hlt

nstart:
		xor al, al
		out	ppi_portc, al	; bsyclk low

		mov	al, 0FFh		; test for warm/cold start
		xor	al, [warm]
		xor	al, [warmh]
		jz gowarm

		mov	ax,0A55Ah
		mov	[warm],al
		mov	[warmh],ah
		
		pop	ds
		pop	ax

		pop	ax		    ; pop unneeded iret
		pop	ax

		popf			; Pop flags
		int	7		    ; jump to OS entry
gowarm:
		pop	ds
		pop	ax
		jmp	server


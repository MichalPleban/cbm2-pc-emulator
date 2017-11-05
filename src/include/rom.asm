
;-----------------------------------------------------------------------------
;     6525 ports
;-----------------------------------------------------------------------------
cia_pra		equ 20h			; port register A (data)
cia_prb		equ 21h			; port register B (com/control)
cia_prc		equ 22h			; port register C
cia_ddra	equ 23h			; data direction register A
cia_ddrb	equ 24h			; data direction register B
cia_ddrc	equ 25h			; data direction register C

pbbus1		equ 01h			; prb0
pbbus2		equ 02h			; prb1
pbsem88		equ 04h			; prb2
pbsem65		equ 08h			; prb3
pbrtn		equ 40h			; prb6

semlo		equ pbrtn		; acknowledge low
semhi		equ pbrtn+pbsem88	; acknowledge hi val


;-----------------------------------------------------------------------------
;     8259A ports
;-----------------------------------------------------------------------------
inta00		equ 00h
inta01		equ 01h

;-----------------------------------------------------------------------------
;     interrupt definitions
;-----------------------------------------------------------------------------
iwait		equ 40h			; go rom, free bus, wait


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



		jmp	rqst900

;-----------------------------------------------------------------------------
; Issue IRQ request to 6509
;
;   enter:  CL = command byte
;           IpcBufr = holds input param bytes
;
;   exit:   IpcBufr = holds output param bytes
;-----------------------------------------------------------------------------
rqster:
		push	ax
		push	bx
		push	cx
		push	dx
		push	si
		push	es
		push	ds

		mov	ax,0
		mov	ds,ax		; set up DS to interrupt area

		mov	ax,[int7seg]	; get segment of ipctab from int 7 vector
		mov	ds,ax

		mov	al,cl		; set dl-#bytes to send
		and	al,7Fh		;     dh-#bytes to receive
		mov	bl,6
		mul	bl		; ax = reg * al
		mov	si,ax
		mov	dx,[si+1Ah]

rqst000:
;
;   Initiate IRQ to 6509, sending CMD byte
;
		in	al,cia_prb
		test	al,pbsem65	; locked out?
		jnz	rqst000		; yes, ->
		
		or	al,4		; lock sem8088
		out	cia_prb,al

		nop

		in	al,cia_prb	
		test	al,pbsem65	; check for collision?
		jz	rqst010		; no, ->

		mov	al,40h		; locked out, clear sem8088
		out	cia_prb,al
		nop

		jmp	short rqst000	;  and try again....
rqst010:
		mov	al,0FFh
		out	cia_ddra,al	; port dir := out

		mov	al,cl
		out	cia_pra,al	; write cmd to port

		in	al,cia_prb	
		and	al,0BFh
		out	cia_prb,al	; cause IRQ (lo -> hi transition)

		nop
		nop
		nop

		or	al,40h
		out	cia_prb,al
rqst030:
		in	al,cia_prb	
		test	al,pbsem65	; IRQ received?
		jz	rqst030		; no, -> wait

		mov	al,0
		out	cia_ddra,al	; port dir := in

		mov	si,0

		inc	dl
		jmp	short rqst120
		
		db	90h

;
;  Send parameter bytes to 6509
;
rqst100:
		mov	al,0FFh
		out	cia_ddra,al	; port dir := out

		mov	al,[ipcbufr+si]
		out	cia_pra,al	; write data to port

		mov	al,semhi
		out	cia_prb,al

		nop
rqst110:
		in	al,cia_prb	
		test	al,pbsem65	; data received?
		jz	rqst110		; no, -> wait

		mov	al,0
		out	cia_ddra,al	; port dir := in

		inc	si
rqst120:
		dec	dl		; decrease count, more to send?
		jz	rqst200		; no, -> ready

		mov	al,semlo
		out	cia_prb,al

		nop
rqst130:
		in	al,cia_prb	
		test	al,pbsem65	; wait for what ???
		jnz	rqst130

		jmp	short rqst100	; and repeat...
		
rqst200:
		test	cl,80h		; need to give up data bus?
		jz	rqst210	; no, ->
		
; Free the bus
		lock	nop
		lock	mov	al,0DFh
		lock	out	cia_prc,al
		lock	nop
		lock	nop
		lock	nop
		lock	or	al,20h
		lock	out	cia_prc,al

		mov	al,semlo
		out	cia_prb,al	; signal to do cmd

		nop
rqstlp:
		jmp	short rqstlp

;
;  Receive data bytes from 6509
;
rqst210:
		mov	al,semlo
		out	cia_prb,al	; signal to do cmd
		
		nop
rqst220:
		in	al,cia_prb	
		test	al,pbsem65	; data available?
		jnz	rqst220		; no, -> wait
		
		mov	si,0
		inc	dh
		jmp	short rqst350
		
		db	90h
rqst310:
		mov	al,semhi
		out	cia_prb,al
		nop
rqst320:
		in	al,cia_prb	
		test	al,pbsem65	; sem8088 -> hi (data available)
		jz	rqst320

		in	al,cia_pra	; read data from port
		mov	[ipcbufr+si],al
		
		mov	al,semlo
		out	cia_prb,al	; sem8088 -> lo (data received)
		nop
rqst330:
		in	al,cia_prb	
		test	al,pbsem65	; sem6509 -> lo (ack ack)
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

		mov	al,semlo
		out	cia_prb,al	; terminate acknowledge
		nop

		pop	si
		pop	ds
		pop	es
		pop	dx
		pop	cx
		pop	bx
		pop	ax
		pop	ax		; pop unneeded IRQ return
		pop	ax
		popf			; Pop flags

		jmp	short rqst400

;-----------------------------------------------------------------------------
;  Service an IRQ from the 6509
;-----------------------------------------------------------------------------
server:
		push	ax
		push	bx
		push	cx
		push	dx
		push	es
		push	ds
		push	si

		mov	ax,0
		mov	ds,ax		; set up DS to interrupt area

		mov	ax,[int7seg]	; get segment of ipctab from int 7 vector
		mov	ds,ax

;
;   Decode the command
;
		in	al,cia_pra	; read cmd byte
		and	al,7Fh
		mov	bl,6		; calculate entry to index
		mul	bl		; ax = reg * al
		mov	si,ax		; get jump address, param counts

		mov	cx,[ipctab+2+si]	; CX := jump address offset
		mov	[start_code+4],cx	; move offset to RAM jump vector
		mov	cx,[ipctab+4+si]	; CX := jump address segment
		mov	[start_code+6],cx	; move segment to RAM jump vector
		mov	dx,[ipctab+si]		; dl = # ins, dh = # outs

		mov	al,semhi
		out	cia_prb,al	; sem8088 -> hi
		nop
rqst050:
		in	al,cia_prb	
		test	al,pbsem65	;sem6509 -> lo (ack)
		jnz	rqst050

		mov	si,0
		inc	dl
		jmp	short serv130
		db	90h

;
;  Get input parameter bytes
;
serv100:
		mov	al,semlo	; sem8088 -> lo (ack ack)
		out	cia_prb,al
		nop
serv110:
		in	al,cia_prb	
		test	al,pbsem65	; sem6509 -> hi (data available)
		jz	serv110

		in	al,cia_pra	; read data
		mov	[ipcbufr+si],al	;  and store it

		mov	al,semhi	; sem8088 -> hi
		out	cia_prb,al
		nop
serv120:
		in	al,cia_prb	
		test	al,pbsem65	; sem6509 -> lo (ack)
		jnz	serv120

		inc	si
serv130:
		dec	dl		; decrease count, more?
		jnz	serv100		; yes, ->

;
;   Process command
;
		push	dx
		push	cs

;		mov	dl,low  offset serv220
		mov	dl,61h
;		mov	dh,high offset serv220
		mov	dh,0F1h

		push	dx		; push return on stack
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
		mov	al,semlo	; sem8088 -> lo (ack ack)
		out	cia_prb,al
		nop
serv310:
		in	al,cia_prb	
		test	al,pbsem65	; sem6509 - > hi (ready to receive)
		jz	serv310

		mov	al,0FFh
		out	cia_ddra,al	; port dir := out

		mov	al,[si+0Ah]
		out	cia_pra,al	; send data byte

		mov	al,semhi	; sem8088 -> hi (data received)
		out	cia_prb,al

		nop
serv320:
		in	al,cia_prb	
		test	al,pbsem65	; sem6509 -> lo (data received)
		jnz	serv320

		mov	al,0
		out	cia_ddra,al	; port dir := in

		inc	si

		dec	dh		; decrease count, more?
		jnz	serv300		; yes, ->
serv400:
		cli			; Disable interrupts

		mov	al,semlo
		out	cia_prb,al	; terminating acknowledge
		nop

		pop	si
		pop	ds
		pop	es
		pop	dx
		pop	cx
		pop	bx
		pop	ax

		iret			; Interrupt return

xret:
xerr:
		retn

;----------------------------------------------------------------------------
;  startup:  do initialization
;----------------------------------------------------------------------------
startf:
		cli			; Disable interrupts

		mov	sp,0F000h

		mov	al,semlo
		out	cia_prb,al

		mov	al,0FFh
		out	cia_pra,al	; port dir := out
		out	cia_prc,al

		inc	al
		out	cia_ddra,al

		mov	al,44h
		out	cia_ddrb,al	; pb4, pb6 = out

		mov	al,20h
		out	cia_ddrc,al	; pc5 = out

; free bus, 0 -> 1 transition on pc5
        	lock	nop
                lock	mov	al,0DFh
                lock	out	cia_prc,al
                lock	nop
                lock	nop
                lock	nop
                lock	or	al,20h
                lock	out	cia_prc,al

;
;   8259A initialization
;
		mov	al,1Bh		; icw1:level, single, icw4
		out	inta00,al

		mov	al,8		; icw2: interrupt address
		out	inta01,al

		mov	al,1		; icw4: 8086 mode
		out	inta01,al

		mov	al,0FEh		; ocw: inhibit I7-I1
		out	inta01,al

		sti			; Enable interrupts

self:
		jmp	short self

;----------------------------------------------------------------------------
;  6509 - gen'd IRQ handler
;             cold IRQ => do cold start
;             warm IRQ => do server, return to requester code.
;----------------------------------------------------------------------------
intrpt:
		push	ax
		push	ds

		mov	ax,0
		mov	ds,ax

		mov	ax,[int7seg]
		mov	ds,ax

		mov	al,20h
		out	0,al		; EOI to 8259A

		in	al,cia_prb	
		test	al,1		; 6509 off bus?
		jz	quit		; no, ->

		in	al,cia_prb	
		test	al,2
		jz	nstart		; yes, ->
quit:
		pop	ds
		pop	ax
		pop	ax
		pop	ax
		pop	ax

		sti			; Enable interrupts

		lock	nop
		lock	mov	al,0DFh
		lock	out	cia_prc,al
		lock	nop
		lock	nop
		lock	nop
		lock	or	al,20h
		lock	out	cia_prc,al
quitl:
		jmp	short quitl	; free bus and sit

nstart:
		mov	al,0
		out	cia_prc,al	; bsyclk low

		mov	al,0FFh		; test for warm/cold start
		xor	al,[warm]
		xor	al,[warmh]
		jz	gowarm

		mov	ax,0A55Ah
		mov	[warm],al
		mov	[warmh],ah
		
		pop	ds
		pop	ax

		pop	ax		; pop unneeded iret
		pop	ax

		popf			; Pop flags
		int	7		; jump to OS entry
gowarm:
		pop	ds
		pop	ax
		jmp	server


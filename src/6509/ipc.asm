

CPU_ACCESS_BANK = $1

;--------------------------------------------------------------------
; Zero page variables
;--------------------------------------------------------------------

tmp_val = $2
buffer_size = $3
old_y = $4
old_x = $5
old_irq = $6
shift_buffer = $10
key_buffer = $20
file_name = $40
load_addr = $43
load_bank = $45

;--------------------------------------------------------------------
; KERNAL variables
;--------------------------------------------------------------------

Status = $9c
CursorLine = $ca
CursorColumn = $cb
LastIndex = $cd
KeybufIndex = $d1
QuoteSwitch = $d2
InsertFlag = $d3
CursorType = $d4
EditorShift = $e0
EditorKey = $e1
IRQVec = $300
GETINVec = $316
SysMemTop = $355
RS232Status = $37a
RvsFlag = $0397
ScrollFlag = $39b
WstFlag = $3fa

;--------------------------------------------------------------------
; I/O chip ports
;--------------------------------------------------------------------

CRTC_RegNo = $d800
CRTC_RegVal = $d801
TPI1_ActIntReg = $de07
ACIA_Command = $DD02
TPI2_PortA = $df00
TPI2_PortB = $df01
TPI2_PortC = $df02


;--------------------------------------------------------------------
; KERNAL routines
;--------------------------------------------------------------------

SCROUT = $e00d
DO_GETIN = $f43d
RUNCOPRO = $ff72
SETST = $ff90
SETLFS = $ffba
SETNAM = $ffbd
OPEN = $ffc0
CLOSE = $ffc3
CHKIN = $ffc6
CHKOUT = $ffc9
CLRCH = $ffcc
BASIN = $ffcf
BSOUT = $ffd2
SETTIM = $ffdb
RDTIM = $ffde
GETIN = $ffe4
PLOT = $fff0

    
;--------------------------------------------------------------------
; Load address for the PRG file
;--------------------------------------------------------------------

    .word $0820
    .org $0820

ipc_buffer = $0805

;--------------------------------------------------------------------
; Some variables moved here to save space.
;--------------------------------------------------------------------

; Filename to open RS-232 channel.
rs232_param:
    .byt $1e,$00
        
; Filename used to open the data channel.
filename_08:
    .byt "#"

; Filename used to open the command channel.
filename_15:
    .byt "I"

; Temporary variable used in address calculation.
calc_tmp:
    .byt $00

; Last key pressed.
last_key:
    .byt $ff

; Delay before repeating the pressed key.
key_delay:
    .byt $00

; Status of the disk operation.
disk_status:
    .byt $a2,$00

; Flag indicating whether "lowercase" character was sent to the printer.
printer_flag:
	.byt 0

; Flag for interrupt nesting.
nesting_flag:
    .byt 1
	
    .res ($0830-*), $FF
        
;--------------------------------------------------------------------
; Jump table to IPC functions (only for function called from 8088).
; The location of this table is hardcoded to $0830 in the KERNAL.
;--------------------------------------------------------------------

    .word ipc_10_kbd_peek
    .word ipc_11_kbd_in
    .word ipc_12_screen_out
    .word ipc_13_printer_out
    .word ipc_14_screen_driver
    .word ipc_15_counter_read
    .word ipc_96_disk_read
    .word ipc_97_disk_write
    .word ipc_18_init
    .word ipc_19_serial_in
    .word ipc_1a_serial_out
    .word ipc_1b_serial_config
    .word 0
    .word ipc_1d_sid_control
    .word 0
    .word 0
    .word ipc_20_kbd_clear
    .word ipc_21_format
    .word ipc_22_dummy
  
;--------------------------------------------------------------------
; Variables used by the code.
;--------------------------------------------------------------------

; Command to read or write disk sector.    
cmd_u1:
    .byt "U1:8 0 ttt sss",$0d

; Command to read or write disk buffer.
cmd_br:
    .byt "B-P 8 0",$0d

; Command to format disk.
cmd_n:
    .byt "N0:MSDOS DISK,88",$0d

;--------------------------------------------------------------------
; IRQ handler function.
; Calls original handler, then launches our keyboard handler.
;--------------------------------------------------------------------
    
my_irq:
    jmp new_irq
    
;--------------------------------------------------------------------
; Actual interrupt handler function.
; Checks keyboard scancodes and places them in our own buffer.
;--------------------------------------------------------------------
    
irq_handler:
    sei
    ldx buffer_size
    cpx #$0e
    bcs irq_end             ; End interrupt if buffer full
    lda KeybufIndex
    bne clear_buffer        ; Read keys from the buffer
    lda EditorKey
    cmp #$ff
    bne has_key             ; 
    lda LastIndex
    cmp #$ff
    bne irq_end
    lda #$ff
    sta last_key
    jmp irq_end
has_key:
    cmp last_key
    beq irq_end
    inc key_delay
    lda key_delay
    cmp #$05
    bne irq_end
clear_buffer:
    lda EditorShift
    and #$38
    sta shift_buffer,x
    lda EditorKey
    sta key_buffer,x
    sta last_key
    inx
    stx buffer_size
    lda #$00
    sta key_delay
irq_end:
    lda #$00
    sta KeybufIndex
    rts
    
;--------------------------------------------------------------------
; IPC function 10 - check scancode in keyboard buffer.
;--------------------------------------------------------------------
    
ipc_10_kbd_peek:
    ldx buffer_size
    beq ipc_10_end
    lda key_buffer
    sta ipc_buffer+2
    lda shift_buffer
    sta ipc_buffer+3
    jmp ipc_22_dummy
ipc_10_end:
    lda EditorShift
    and #$38
    sta ipc_buffer+3
ipc_22_dummy:
    clc
    jmp ipc_end
    
;--------------------------------------------------------------------
; IPC function 20 - clear keyboard buffer.
;--------------------------------------------------------------------    
    
ipc_20_kbd_clear:
    lda #$00
    sta buffer_size
    sta KeybufIndex
    rts

;--------------------------------------------------------------------
; IPC function 11 - read from keyboard.
;--------------------------------------------------------------------
    
ipc_11_kbd_in:
    ldx #$01
    jsr CHKIN
ipc_11_loop:
    jsr GETIN
    beq ipc_11_loop
    sta ipc_buffer+2
    sty ipc_buffer+3
    jsr CLRCH
    clc
    jmp ipc_end

;--------------------------------------------------------------------
; Information about IPC function parameters. For every function:
;  * low nibble = number of input parameters.
;  * hight nibble = number of output parameters.
; The location of this table is hardcoded to $0910 in the KERNAL.
;--------------------------------------------------------------------        

    .res ($0910-*), $FF
    
    .byt $00,$01,$02,$03,$04,$05,$06,$07
    .byt $08,$09,$0a,$0b,$0c,$0d,$0e,$0f
    .byt $40,$40,$23,$23,$66,$40,$4b,$4b
    .byt $40,$30,$23,$25,$00,$25,$00,$00
    .byt $00,$4b,$0a
    
    
;--------------------------------------------------------------------
; IPC function 12 - write to screen.
;--------------------------------------------------------------------

ipc_12_screen_out:
    ldx #$03
    jsr CHKOUT
    lda ipc_buffer+2
    jsr uppercase_convert
    jsr BSOUT
    lda #$00
    sta QuoteSwitch
    sta InsertFlag
    jsr CLRCH
    clc
    jmp ipc_end
    
;--------------------------------------------------------------------
; IPC function 19 - read from RS-232.
;--------------------------------------------------------------------
    
ipc_19_serial_in:
    ldx #$02
    jsr CHKIN
    ; Release the RTS line so that serial data can arrive
serial_read:
    jsr DO_GETIN
    sta ipc_buffer+2
    lda RS232Status
    and #$10
    bne serial_read
serial_checkstatus:
    jsr CLRCH
    ; Assert the RTS line again
    lda RS232Status
    clc
    and #$77
    beq ipc_19_end
    sec
ipc_19_end:
    jmp ipc_end
    
;--------------------------------------------------------------------
; IPC function 1A - write to RS-232.
;--------------------------------------------------------------------
    
ipc_1a_serial_out:
    ldx #$02
    jsr CHKOUT
    lda ipc_buffer+2
    jsr BSOUT
    jmp serial_checkstatus
    
    
;--------------------------------------------------------------------
; IPC function 96 - read disk sector.
;--------------------------------------------------------------------
    
read_init:
    plp
    lda ipc_buffer+2
    and #$02
    bne read_09
    jsr reopen_08
    jmp read_init_2
read_09:
    jsr reopen_09
read_init_2:
    bcs disk_end

ipc_96_disk_read:
    jsr calc_addr
    lda #$31
    jsr set_sector
    php
    lda disk_status
    ora disk_status+1
    cmp #$37
    beq read_init
    plp
    bcs disk_end
    jsr drive_read
    bcs disk_end
    ldx CPU_ACCESS_BANK
    ldy load_bank
    sty CPU_ACCESS_BANK
    ldy #$00
read_loop:
    jsr BASIN
    sta (load_addr),y
    iny
    beq read_end
    lda load_addr+1
    cmp #$ff
    bne read_loop
    tya
    clc
    adc load_addr
    bne read_loop
    inc CPU_ACCESS_BANK
    jmp read_loop
read_end:
    stx CPU_ACCESS_BANK
    clc
disk_end:
    lda disk_status
    sta ipc_buffer+2
    lda disk_status+1
    sta ipc_buffer+3
    jsr ipc_end
    jmp CLRCH
    
;--------------------------------------------------------------------
; IPC function 97 - write disk sector.
;--------------------------------------------------------------------
    
write_init:
    lda ipc_buffer+2
    and #$02
    bne write_09
    jsr reopen_08
    jmp write_init_2
write_09:
    jsr reopen_09
write_init_2:
    bcs disk_end

ipc_97_disk_write:
    jsr calc_addr
    jsr prepare_channel
    bcs disk_end
    ldx #$00
    ldy #$08
loop_br:
    lda cmd_br,x
    jsr BSOUT
    inx
    dey
    bne loop_br
    jsr CLRCH
    jsr read_disk
    bcs disk_end
    cmp #$30
    bne write_init
    jsr CLRCH
    jsr drive_write
    bcs disk_end
    ldx CPU_ACCESS_BANK
    ldy load_bank
    sty CPU_ACCESS_BANK
    ldy #$00
write_loop:
    lda (load_addr),y
    jsr BSOUT
    iny
    bne write_loop
    stx CPU_ACCESS_BANK
    jsr CLRCH
    lda #$32
    jsr set_sector
    jmp disk_end
    
;--------------------------------------------------------------------
; Disk support functions.
;--------------------------------------------------------------------
    
set_sector:
    sta cmd_u1+1
    lda ipc_buffer+2
    and #$01
    clc
    adc #$30
    sta cmd_u1+5
    ldy ipc_buffer+3
    lda ipc_buffer+4
    jsr bin_to_dec
    sty cmd_u1+7
    stx cmd_u1+8
    sta cmd_u1+9
    ldy ipc_buffer+5
    lda ipc_buffer+6
    jsr bin_to_dec
    sty cmd_u1+11
    stx cmd_u1+12
    sta cmd_u1+13
    jsr prepare_channel
    bcs disk_error
    ldx #$00
loop_u1:
    lda cmd_u1,x
    jsr BSOUT
    inx
    cpx #$0F
    bne loop_u1
    jsr CLRCH
    jsr read_disk
    bcs disk_error
    sta disk_status
    jsr BASIN
    sta disk_status+1
    ora disk_status
    cmp #$30
    bne check_status
    clc
    rts
check_status:
    lda disk_status+1
    cmp #$39
    bne disk_error
    lda disk_status
    cmp #$32
    bne disk_error
    jsr reopen_08
    jmp set_sector
disk_error:
    sec
    rts

; Prepare I/O channels to the disk.    
prepare_error:
    jsr reopen_08
    bcs status_reset
prepare_channel:
    jsr calc_fileno
    jsr CHKOUT
    bcs prepare_error
    ldx #$00
status_reset:
    lda #$3f
    sta disk_status
    sta disk_status+1
    rts
reopen_disk:
    jsr reopen_08
    bcs status_reset
read_disk:
    jsr calc_fileno
    jsr CHKIN
    bcs reopen_disk
    
; Call BASIN function.
my_BASIN:
    jsr BASIN
    rts
    
; Set data channel (8 or 9) as input.
drive_read2:
    jsr reopen_08
    bcs status_reset
drive_read:
    jsr calc_drive
    jsr CHKIN
    bcs drive_read2
    rts
    
; Set data channel (8 or 9) as output.
drive_write2:
    jsr reopen_08
    bcs status_reset
drive_write:
    jsr calc_drive
    jsr CHKOUT
    bcs drive_write2
    rts
    
; Calculate command channel number (15 or 16).
calc_fileno:
    lda ipc_buffer+2
    and #$02
    lsr
    clc
    adc #$0f
    tax
    rts

; Calculate data channel number (8 or 9).
calc_drive:
    lda ipc_buffer+2
    and #$02
    lsr
    clc
    adc #$08
    tax
    rts

; Calculate address from 8088 segment and offset.
calc_addr:
    sta TPI1_ActIntReg
    lda ipc_buffer+10
    sta load_addr
    lda ipc_buffer+9
    sta load_addr+1
    lda #$00
    sta load_bank
    lda #$04
    sta calc_tmp
loop_addr_1:
    ldy #$00
    ldx #$03
    clc
loop_addr_2:
    lda load_addr,y
    rol
    sta load_addr,y
    iny
    dex
    bne loop_addr_2
    dec calc_tmp
    bne loop_addr_1
    clc
    lda load_addr
    adc ipc_buffer+8
    sta load_addr
    lda load_addr+1
    adc ipc_buffer+7
    sta load_addr+1
    lda load_bank
    adc #$01
    sta load_bank
    rts
    
;--------------------------------------------------------------------
; IPC function 18 - initialize the I/O library.
;--------------------------------------------------------------------
    
ipc_18_init:
    lda #$80
    jsr SETST
    lda #$ff
    sta EditorKey
    jsr reopen_08
    lda #$00
    sta ipc_buffer+2
    jsr reopen_09
    bcs init_diskno
    inc ipc_buffer+2
init_diskno:
    jsr serial_reopen
    lda #$01
    ldx #$00
    stx QuoteSwitch
    stx InsertFlag
    stx buffer_size
    stx KeybufIndex
    jsr SETLFS
    clc
    jsr OPEN
    lda #$03
    tax
    jsr SETLFS
    clc
    jsr OPEN
    jsr printer_reopen
    lda #$60
    ldx #$0a
    stx CRTC_RegNo
    sta CRTC_RegVal
    sta CursorType
    lda #$40
    sta ScrollFlag
    sei
    lda IRQVec
    sta old_irq
    lda IRQVec+1
    sta old_irq+1
    lda #<my_irq
    sta IRQVec
    lda #>my_irq
    sta IRQVec+1
    cli
    lda #<my_getin
    sta GETINVec
    lda #>my_getin
    sta GETINVec+1
    ; Initialize 18.2 Hz counter
    lda #$D6
    sta $db07
    lda #$93
    sta $db06
    lda #$17
    sta $db0f
    lda #$FF
    sta $db05
    sta $db04
    lda #$B1
    sta $db0e
    ; Initialize SID second voice
    lda #$0F
    sta $DA18
    lda #$00
    sta $DA07
    sta $DA08
    sta $DA09
    sta $DA0C
    lda #$08
    sta $DA0A
    lda #$F0
    sta $DA0D
    lda #$20
    sta $DA0B
    jmp ipc_end
    
;--------------------------------------------------------------------
; Further disk support functions.
;--------------------------------------------------------------------

; Reopen data channel 8 to disk #8.
reopen_08:
    lda #$08
    jsr my_CLOSE
    lda #$0f
    jsr my_CLOSE
    lda #$0f
    ldx #$08
    jsr open_15
    bcc do_open_08
    rts
do_open_08:
    lda #$08
    jsr open_08
    rts

; Reopen data channel 9 to disk #9.
reopen_09:
    lda #$09
    jsr my_CLOSE
    lda #$10
    jsr my_CLOSE
    lda #$10
    ldx #$09
    jsr open_15
    bcc do_open_09
    rts
do_open_09:
    lda Status
    and #$80
    beq open_09
    sec
    rts

open_09:
    lda #$09
    jsr open_08
    rts
    
; Open command channel to disk.
open_15:
    ldy #$0f
    jsr SETLFS
    lda #<filename_15
    ldx #>filename_15
    ldy #$0f
    sta file_name
    stx file_name+1
    sty file_name+2
    lda #$01
    ldx #$40
    jsr SETNAM
    jsr my_OPEN
    rts

; Reopen data channel to disk.
open_08:
    tax
    ldy #$08
    jsr SETLFS
    lda #<filename_08
    ldx #>filename_08
    ldy #$0f
    sta file_name
    stx file_name+1
    sty file_name+2
    lda #$01
    ldx #$40
    jsr SETNAM
    jsr my_OPEN
    rts
    
; Reopen channel #3 to RS-232 with new parameters.
serial_reopen:
    lda #$02
    jsr my_CLOSE
    lda #$ff
    sta SysMemTop
    lda #$0f
    sta SysMemTop+2
    sta SysMemTop+1
    lda #$02
    tax
    ldy #$03
    jsr SETLFS
    lda #<rs232_param
    ldx #>rs232_param
    ldy #$0f
    sta file_name
    stx file_name+1
    sty file_name+2
    lda #$02
    ldx #$40
    jsr SETNAM
    jsr my_OPEN
    ldx #$02
    jsr CHKIN
    jmp DO_GETIN
    
;--------------------------------------------------------------------
; IPC function 13 - write to printer.
;--------------------------------------------------------------------
    
ipc_13_printer_out:
    lda ipc_buffer+2
    clc
    bmi printer_end
    cmp #$0d
    beq printer_cr
    cmp #$20
    bcc printer_end
    jsr uppercase_convert
printer_print:
	jsr printer_out
printer_end:
    jmp ipc_end
printer_cr:
	jsr printer_out
	ldx #0
	stx printer_flag
	clc
	bcc printer_end
	
printer_out:
	pha
    ldx #$04
    jsr CHKOUT
    bcc printer_ok
    jsr printer_reopen
    bcs printer_finish
    ldx #$04
    jsr CHKOUT
    bcs printer_finish
printer_ok:
    bit printer_flag
    bmi printer_do
    lda #$11
    jsr BSOUT
    lda #$80
    sta printer_flag
printer_do:
    pla
    jsr BSOUT
    jsr CLRCH
    clc
    rts
printer_finish:
	pla
	rts
	    
; Reopen channel #4 to printer in case of error.
printer_reopen:
    lda #$04
    jsr my_CLOSE
    lda #$04
    ldx #$04
    ldy #$67
    jsr SETLFS
    lda #$00
    jsr SETNAM
    jsr my_OPEN
    ldx #$04
    jsr CHKOUT
    lda #$0d
    jsr BSOUT
    jsr CLRCH
    lda #$04
    jsr my_CLOSE
    lda #$04
    ldx #$04
    ldy #$60
    jsr SETLFS
my_OPEN:
    clc
    jmp OPEN
my_CLOSE:
    sec
    jmp CLOSE
    
;--------------------------------------------------------------------
; IPC function 21 - format disk.
;--------------------------------------------------------------------
    
ipc_21_format:
    lda ipc_buffer+2
    and #$01
    clc
    adc #$30
    sta cmd_n+1
    jsr prepare_channel
    bcs format_end
    ldx #$00
    ldy #$11
format_loop:
    lda cmd_n,x
    jsr BSOUT
    bcs format_end
    inx
    dey
    bne format_loop
    jsr CLRCH
    ldx #$0f
    jsr CHKIN
    bcs format_end
    jsr BASIN
    cmp #$30
    bne format_end
    clc
format_end2:
    jsr ipc_end
    jmp CLRCH
format_end:
    sec
    bne format_end2
    
;--------------------------------------------------------------------
; Convert byte to ASCII decimal representation.
;--------------------------------------------------------------------    

bin_to_dec:
    jsr convert_digit
    pha
    dex
    txa
    jsr convert_digit
    pha
    dex
    txa
    clc
    adc #$30
    tay
    pla
    tax
    pla
    rts
    
convert_digit:
    ldx #$00
    sec
convert_1:
    inx
    sbc #$0a
    bcs convert_1
    adc #$3a
    rts
    
;--------------------------------------------------------------------
; Finish IPC function.
; Set status byte and keyboard buffer byte.
;--------------------------------------------------------------------
    
ipc_end:
    lda #$00
    ror
    sta ipc_buffer
    lda buffer_size
    beq end_nokey
    lda #$01
end_nokey:
    ora #$fe
    sta ipc_buffer+1
    rts
    
;--------------------------------------------------------------------
; IPC function 1B - configure RS-232 port.
;--------------------------------------------------------------------
    
ipc_1b_serial_config:
    lda ipc_buffer+2
    sta rs232_param
    lda ipc_buffer+3
    sta rs232_param+1
    jsr serial_reopen
    jmp ipc_end


;--------------------------------------------------------------------
; Replacement function for GETIN.
; Reads scancodes from our own buffer instead of the system one.
;--------------------------------------------------------------------
    
my_getin:
    lda buffer_size
    beq getin_end
    sei
    ldy shift_buffer
    lda key_buffer
    pha
    ldx #$00
getin_loop:
    lda shift_buffer+1,x
    sta shift_buffer,x
    lda key_buffer+1,x
    sta key_buffer,x
    inx
    cpx buffer_size
    bne getin_loop
    dec buffer_size
    pla
    ldx #$03
getin_end:
    clc
    rts

;--------------------------------------------------------------------
; Change character case from ASCII to PETSCII
;--------------------------------------------------------------------

uppercase_convert:
    cmp #$41
    bcc uppercase_convert_2
    cmp #$5B
    bcc uppercase_convert_1
    cmp #$61
    bcc uppercase_convert_2
    cmp #$7B
    bcs uppercase_convert_2
uppercase_convert_1:
    eor #$20
uppercase_convert_2:
    cmp #$60
    bcc uppercase_convert_3
    adc #$5F
uppercase_convert_3:
	rts

;--------------------------------------------------------------------
; IPC function 14 - screen driver
;--------------------------------------------------------------------
    
ipc_14_screen_driver:
    jsr $0403
    rts

;--------------------------------------------------------------------
; IPC function 15 - read CIA counter A
;--------------------------------------------------------------------
    
ipc_15_counter_read:
    lda $db04
    eor #$FF
    sta ipc_buffer+2
    lda $db05
    eor #$FF
    sta ipc_buffer+3
    lda #$B1
    sta $db0e
    clc
    jmp ipc_end

;--------------------------------------------------------------------
; IPC function 1D - read CIA counter A
;--------------------------------------------------------------------
    
ipc_1d_sid_control:
    lda ipc_buffer+2
    sta $0FFD
    sta $DA07
    lda ipc_buffer+3
    sta $0FFE
    sta $DA08
    lda ipc_buffer+4
    and #$01
    ora #$20
    sta $DA0B
    clc
    jmp ipc_end

;--------------------------------------------------------------------
; New IRQ Handler
;--------------------------------------------------------------------

new_irq:
    lda $01
    pha
    cld
    ; Check TPI interrupt source
    lda $DE07
    bne new_irq_1
    sta $DE07
    jmp $FCA2
new_irq_1:
    ; IRQ from the 8088? If yes, redirect to our handler.
    cmp #$08
    beq new_irq_2
    ; IRQ from 50Hz timer? If yes, redirect to our handler.
    cmp #$01
    beq new_irq_5
    ; Redirect to normal IRQ handler.
    jmp $FBF5
new_irq_2:
    ; Clear IRQ flag at the CIA
    lda $DB0D
    ; Decrease nesting level
    dec nesting_flag
    ; Nested interrupt? If yes then exit.
    bit nesting_flag
    bmi new_irq_4
new_irq_3:
    cli
    lda #$00
    sta $DB02
    lda $DB00
    jsr $FD48
    inc nesting_flag
    ; Nested interrupt arrived in the meantime? If yes then repeat.
    lda nesting_flag
    cmp #1
    bne new_irq_3
new_irq_4:
    jmp $FC9F
new_irq_5:
    jsr new_scnkey
    jsr $F979
    sei
    jsr irq_handler
    jmp $FC9F

;--------------------------------------------------------------------
; New keyboard scan function
;--------------------------------------------------------------------

new_scnkey:
    ldy     #$FF
    sty     EditorShift
    sty     EditorKey
    iny
    sty     TPI2_PortB
    sty     TPI2_PortA
    jsr     $E91E
    and     #$3F
    eor     #$3F
    bne     new_scnkey_process
new_scnkey_nokey:
    jmp     $E8F3
new_scnkey_process:
    ; Additional code to detect C= press
    lda     #$FF
    sta     TPI2_PortB
    ldx     #$F7
    stx     TPI2_PortA
    jsr     $E91E
    lsr     a
    ora     #$F7
    sta     EditorShift
    lda     #$FF
    sta     TPI2_PortA
    asl     a
    sta     TPI2_PortB
    jsr     $E91E
    pha
    ora     #$07
    and     EditorShift
    sta     EditorShift
    pla
    pha
    ora     #$30
    bne     new_scnkey_process_2
new_scnkey_process_1:
    jsr     $E91E
new_scnkey_process_2:
    ldx     #$05
new_scnkey_process_3:
    lsr     a
    bcc     new_scnkey_haskey
new_scnkey_process_4:
    iny
    dex
    bpl     new_scnkey_process_3
    sec
    rol     TPI2_PortB
    rol     TPI2_PortA
    bcs     new_scnkey_process_1
    pla
    bcc     new_scnkey_nokey
new_scnkey_haskey:
    ; Ignore C= key
    cpy     #70
    beq     new_scnkey_process_4
    jmp     $E8A9

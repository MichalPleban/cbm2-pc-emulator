

CPU_ACCESS_BANK = $1

;--------------------------------------------------------------------
; Zero page variables
;--------------------------------------------------------------------

src_addr = $50
page_count = $52
dst_page = $53

CursorType = $D4
jmp_vector = $03FC

;--------------------------------------------------------------------
; I/O chip ports
;--------------------------------------------------------------------

CRTC_RegNo = $D800
CRTC_RegVal = $D801

VGA_CMD = $DABC
VGA_DATA = $DABD

;--------------------------------------------------------------------
; KERNAL routines
;--------------------------------------------------------------------

PLOT = $fff0

;--------------------------------------------------------------------
; Load address for the PRG file
;--------------------------------------------------------------------

    .word $0400
    .org $0400

ipc_buffer = $0805

    rts
    nop
    nop
    jmp ipc_14_video


;--------------------------------------------------------------------
; IPC function 14 (video services) handler.
;--------------------------------------------------------------------

ipc_14_video:
    lda ipc_buffer
    asl
    tax
    lda func_table,x
    sta jmp_vector
    lda func_table+1,x
    sta jmp_vector+1
    jmp (jmp_vector)
    

func_table:
    .word func_00_screen_init
    .word func_01_set_cursor
    .word func_02_screen_convert
    .word func_03_clear_screen
    .word func_04_scroll_up
    .word func_05_set_cursor

;--------------------------------------------------------------------
; Function 00: Initialize screen.
;--------------------------------------------------------------------

func_00_screen_init:
    ; Switch on MDA mode
    lda #$81
    sta VGA_CMD
    ; Disable CRTC cursor
    lda #$20
    ldx #$0A
    stx CRTC_RegNo 
    sta CRTC_RegVal
    sta CursorType
    ; Clear the lower part of the CRTC screen
    ldy #$00
    lda #$20
clear_loop:
    sta $D500,y
    sta $D600,y
    sta $D700,y
    dey
    bne clear_loop
    rts
    
;--------------------------------------------------------------------
; Function 01: Set cursor position
;--------------------------------------------------------------------

func_01_set_cursor:
    ldy ipc_buffer+1
    ldx ipc_buffer+2
    clc
    jmp PLOT
        
;--------------------------------------------------------------------
; Function 02: Convert the PC screen to video memory.
;--------------------------------------------------------------------
    
func_02_screen_convert:
    ; Calculate and initialize addresses
    lda #$0C
    sta CPU_ACCESS_BANK
    lda #8
    sta page_count
    lda ipc_buffer+1
    asl 
    asl 
    asl 
    asl
    sta src_addr+1
    ldy #$01
    sty src_addr
    lda #$00
    sta dst_page
    
    ; Convert the screen
    jsr screen_convert
    lda #15
    sta CPU_ACCESS_BANK
    rts
    
;--------------------------------------------------------------------
; Screen conversion routine.
;--------------------------------------------------------------------

screen_convert:
    lda dst_page
    sta VGA_CMD
    lsr ipc_buffer+2
    bcs screen_convert_start
    inc src_addr+1
    bne screen_convert_skip
screen_convert_start:
    lda src_addr
    beq screen_convert_do
    ; Convert first two bytes
    lda ipc_buffer+3
    sta VGA_DATA
    lda ipc_buffer+4
    sta VGA_DATA
screen_convert_do:
    lda (src_addr),y
    sta VGA_DATA
    inc src_addr
    bne screen_proc_page
    inc src_addr+1
screen_proc_page:
    lda (src_addr),y
    sta VGA_DATA
    iny
    bne screen_convert_do
screen_convert_skip:
    ldy #0
    sty src_addr
    inc src_addr+1
    inc dst_page
    dec page_count
    bne screen_convert
    rts
screen_proc_end:


;--------------------------------------------------------------------
; Function 03: Clear screen
;--------------------------------------------------------------------

func_03_clear_screen:
    lda #$82
    sta VGA_CMD
    rts

;--------------------------------------------------------------------
; Function 04: Scroll screen up
;--------------------------------------------------------------------

func_04_scroll_up:
    lda #$83
    sta VGA_CMD
    ; TODO: Why is this needed? Delay in the Propeller?
    lda #$81
    sta ipc_buffer+2
    jmp func_02_screen_convert
    

;--------------------------------------------------------------------
; Function 05: Set cursor (not yet implemented)
;--------------------------------------------------------------------

func_05_set_cursor:
    lda ipc_buffer+1
    bmi set_cursor_off
    lda #$84
    .byt $2c
set_cursor_off:
    lda #$85
    sta VGA_CMD
    rts

;--------------------------------------------------------------------
; ASCII to PETSCII (standard char ROM)
;--------------------------------------------------------------------

petscii_table:
	.byt $60, $64, $64, $64, $64, $64, $64, $2a, $aa, $2a, $aa, $64, $64, $64, $64, $64
	.byt $3e, $3c, $5d, $64, $64, $64, $62, $5d, $1e, $16, $3e, $3c, $64, $64, $1e, $16
	.byt $20, $21, $22, $23, $24, $25, $26, $27, $28, $29, $2a, $2b, $2c, $2d, $2e, $2f
	.byt $30, $31, $32, $33, $34, $35, $36, $37, $38, $39, $3a, $3b, $3c, $3d, $3e, $3f
	.byt $00, $41, $42, $43, $44, $45, $46, $47, $48, $49, $4a, $4b, $4c, $4d, $4e, $4f
	.byt $50, $51, $52, $53, $54, $55, $56, $57, $58, $59, $5a, $1b, $1c, $1d, $1e, $1f
	.byt $40, $01, $02, $03, $04, $05, $06, $07, $08, $09, $0a, $0b, $0c, $0d, $0e, $0f
	.byt $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $1a, $5b, $5c, $5d, $5e, $1e
	.byt $64, $64, $64, $64, $64, $64, $64, $64, $64, $64, $64, $64, $64, $64, $64, $64
	.byt $64, $64, $64, $64, $64, $64, $64, $64, $64, $64, $64, $64, $0c, $64, $64, $64
	.byt $64, $64, $64, $64, $64, $64, $64, $64, $64, $64, $64, $64, $64, $64, $3c, $3e
	.byt $66, $5f, $5f, $5d, $73, $73, $73, $6e, $6e, $73, $5d, $6e, $7d, $7d, $7d, $6e
	.byt $6d, $71, $72, $6b, $40, $5b, $6b, $6b, $6d, $70, $71, $72, $6b, $40, $5b, $71
	.byt $71, $72, $72, $6d, $6d, $70, $70, $5b, $5b, $7d, $70, $e0, $62, $61, $e1, $e2
	.byt $64, $64, $64, $64, $64, $64, $64, $64, $64, $64, $64, $64, $64, $64, $64, $64
	.byt $64, $64, $64, $64, $64, $64, $64, $64, $64, $2a, $2a, $7a, $64, $64, $2a, $60


;--------------------------------------------------------------------
; Attribute conversion (MDA to reverse bit)
;--------------------------------------------------------------------
	
petscii_table_2:
	.byt $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
	.byt $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
	.byt $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
	.byt $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
	.byt $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
	.byt $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
	.byt $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
	.byt $80, $00, $00, $00, $00, $00, $00, $00, $80, $00, $00, $00, $00, $00, $00, $00
	.byt $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
	.byt $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
	.byt $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
	.byt $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
	.byt $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
	.byt $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
	.byt $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
	.byt $80, $00, $00, $00, $00, $00, $00, $00, $80, $00, $00, $00, $00, $00, $00, $00

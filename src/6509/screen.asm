

CPU_ACCESS_BANK = $1
PROC_ADDR = $0100

;--------------------------------------------------------------------
; Zero page variables
;--------------------------------------------------------------------

src_addr = $50
page_count = $52
tmp_byte = $53

jmp_vector = $03FC;

;--------------------------------------------------------------------
; I/O chip ports
;--------------------------------------------------------------------

CRTC_RegNo = $d800
CRTC_RegVal = $d801

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

;--------------------------------------------------------------------
; Function 00: Initialize screen.
;--------------------------------------------------------------------

func_00_screen_init:
    ldx #$0E
    stx CRTC_RegNo
.ifdef NOCHAR
    lda #$EF
    and CRTC_RegVal
.endif
.ifdef CHAR
    lda #$10
    ora CRTC_RegVal
.endif
    sta CRTC_RegVal
    and #$30
    ldx #$0C
    stx CRTC_RegNo
    sta CRTC_RegVal
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
    lda #$D0
    sta screen_proc_dst+2
    lda ipc_buffer+1
    asl 
    asl 
    asl 
    asl
    sta src_addr+1
    ldy #$01
    sty src_addr
    
    ; Convert the screen
    jsr screen_convert
    lda #15
    sta CPU_ACCESS_BANK
    
    ; Convert first byte
    ldx ipc_buffer+3
    lda petscii_table,x
    sta tmp_byte
    ldx ipc_buffer+4
    lda petscii_table_2,x
    ora tmp_byte
    sta $D000
    rts
    
;--------------------------------------------------------------------
; Screen conversion routine.
;--------------------------------------------------------------------

screen_convert:
    lsr ipc_buffer+2
    bcs screen_convert_do
    inc src_addr+1
    bne screen_convert_skip
screen_convert_do:
    lda (src_addr),y
    tax
    lda petscii_table,x
    sta tmp_byte
    inc src_addr
    bne screen_proc_page
    inc src_addr+1
screen_proc_page:
    lda (src_addr),y
    tax
    lda petscii_table_2,x
    ora tmp_byte
screen_proc_dst:
    sta $D000,y
    iny
    bne screen_convert_do
screen_convert_skip:
    inc src_addr+1
    inc screen_proc_dst+2
    dec page_count
    bne screen_convert
    lda $D7D0
    sta $D000
    rts
screen_proc_end:


;--------------------------------------------------------------------
; Function 03: Clear screen
;--------------------------------------------------------------------

func_03_clear_screen:
    ldx #8
    lda #$D0
    sta screen_clear_dst+2
    lda #$00
    sta screen_clear_dst+1
screen_clear_loop:
    ldy #0
    lda #$20
screen_clear_dst:
    sta $D000,y
    iny 
    cpy #250
    bne screen_clear_dst
    lda screen_clear_dst+1
    clc
    adc #250
    sta screen_clear_dst+1
    lda screen_clear_dst+2
    adc #0
    sta screen_clear_dst+2
    dex
    bne screen_clear_loop
    rts

;--------------------------------------------------------------------
; Function 04: Scroll screen up
;--------------------------------------------------------------------

func_04_scroll_up:
    ldx #8
    lda #$D0
    sta screen_scroll_src+2
    sta screen_scroll_dst+2
    lda #$00
    sta screen_scroll_dst+1
    lda #$50
    sta screen_scroll_src+1
screen_scroll_loop:
    ldy #0
screen_scroll_src:
    lda $D050,y
screen_scroll_dst:
    sta $D000,y
    iny 
    cpy #240
    bne screen_scroll_src
    lda screen_scroll_src+1
    clc
    adc #240
    sta screen_scroll_src+1
    lda screen_scroll_src+2
    adc #0
    sta screen_scroll_src+2
    lda screen_scroll_dst+1
    clc
    adc #240
    sta screen_scroll_dst+1
    lda screen_scroll_dst+2
    adc #0
    sta screen_scroll_dst+2
    dex
    bne screen_scroll_loop
    ldy #79
    lda #$20
screen_scroll_clear:
    sta $D780,y
    dey
    bpl screen_scroll_clear
    rts
    

.ifdef NOCHAR

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

.endif 

.ifdef CHAR

;--------------------------------------------------------------------
; ASCII to PETSCII (modified char ROM)
;--------------------------------------------------------------------
	
petscii_table:
	.byt $7f, $5f, $5f, $5f, $5f, $5f, $5f, $7c, $7d, $7c, $7d, $5f, $5f, $5f, $5f, $5f
	.byt $76, $75, $7a, $5f, $5f, $5f, $62, $7a, $77, $78, $76, $75, $5f, $5f, $77, $78
	.byt $20, $21, $22, $23, $24, $25, $26, $27, $28, $29, $2a, $2b, $2c, $2d, $2e, $2f
	.byt $30, $31, $32, $33, $34, $35, $36, $37, $38, $39, $3a, $3b, $3c, $3d, $3e, $3f
	.byt $00, $41, $42, $43, $44, $45, $46, $47, $48, $49, $4a, $4b, $4c, $4d, $4e, $4f
	.byt $50, $51, $52, $53, $54, $55, $56, $57, $58, $59, $5a, $1b, $1c, $1d, $1e, $1f
	.byt $40, $01, $02, $03, $04, $05, $06, $07, $08, $09, $0a, $0b, $0c, $0d, $0e, $0f
	.byt $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $1a, $5b, $5c, $5d, $5e, $77
	.byt $5f, $5f, $5f, $5f, $5f, $5f, $5f, $5f, $5f, $5f, $5f, $5f, $5f, $5f, $5f, $5f
	.byt $5f, $5f, $5f, $5f, $5f, $5f, $5f, $5f, $5f, $5f, $5f, $5f, $7e, $5f, $5f, $5f
	.byt $5f, $5f, $5f, $5f, $5f, $5f, $5f, $5f, $5f, $5f, $5f, $5f, $5f, $5f, $75, $76
	.byt $69, $68, $6a, $65, $6c, $6c, $6c, $6f, $6f, $6c, $65, $6f, $71, $71, $71, $6f
	.byt $72, $6d, $6e, $6b, $66, $67, $6b, $6b, $72, $70, $6d, $6e, $6b, $66, $67, $6d
	.byt $6d, $6e, $6e, $72, $72, $70, $70, $67, $67, $71, $70, $60, $62, $61, $64, $63
	.byt $5f, $5f, $5f, $5f, $5f, $5f, $5f, $5f, $5f, $5f, $5f, $5f, $5f, $5f, $5f, $5f
	.byt $5f, $5f, $5f, $5f, $5f, $5f, $5f, $5f, $5f, $7c, $7c, $79, $5f, $5f, $74, $7f

.endif 

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

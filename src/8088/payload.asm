
[CPU 8086]

%define ROM

            org 00000h
            
            ; Jump to IPC IRQ routine for legacy software            
            jmp 0F000h:0F000h

            ; Include version and build number
%include 'src/8088/build.inc'

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

            ; Total payload length
            dw PayloadEnd
            
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

            ; File type, load bank & address
            db 80h
            db 00h
            dw 0000h
            ; Link to next file
            dw File80End
RomInit:
            call IPC_Install
            call IPC_Reset
            call Init_Data
            call Init_INT
            call Hardware_Init
            call Screen_Init
            call Virtual_Init
            xor ah, ah
            int 10h
            call Version_Output
            call Hardware_Check
RomLoop:
            int 19h
            jmp RomLoop


%include 'src/8088/payload/init.asm'
%include 'src/8088/payload/sd.asm'
%include 'src/8088/payload/i2c.asm'
%include 'src/8088/payload/debug.asm'
%include 'src/8088/payload/data.asm'
%include 'src/8088/payload/ipc.asm'
%include 'src/8088/payload/screen.asm'
%include 'src/8088/payload/int.asm'
%include 'src/8088/payload/config.asm'
%include 'src/8088/payload/hardware.asm'
%include 'src/8088/payload/virtual.asm'

            ; End of file 80
File80End:

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

            ; File type, load bank & address
            db 00h          ;  00 (6509 IPC library)
            db 0Fh
            dw 0820h
            ; Link to next file
            dw File00End
incbin 'dist/prg/6509.prg'
File00End:

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

            ; File type, load bank & address
            db 10h          ; 01 (standard screen driver)
            db 0Fh
            dw 0400h
            ; Link to next file
            dw File10End
incbin 'dist/prg/screen_nochar.prg'
File10End:

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

            ; File type, load bank & address
            db 11h           ; 11 (screen driver with PC font)
            db 0Fh
            dw 0400h
            ; Link to next file
            dw File11End
incbin 'dist/prg/screen_char.prg'
File11End:

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

            ; File type, load bank & address
            db 12h           ; 12 (VGA interface driver)
            db 0Fh
            dw 0400h
            ; Link to next file
            dw File12End
incbin 'dist/prg/vga.prg'
File12End:

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

            ; End of binary payload
            db 0FFh
PayloadEnd:

            ; Padding for cbmlink memory transfer
    		times 16 db 0FFh	

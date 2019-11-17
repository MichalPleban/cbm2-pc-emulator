
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
            call Screen_Init
            xor ah, ah
            int 10h
            call Version_Output
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

            ; End of file 80
File80End:

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

            ; File type, load bank & address
            db 00h
            db 0Fh
            dw 0800h
            ; Link to next file
            dw File00End
incbin 'dist/prg/6509.prg'
File00End:

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

            ; File type, load bank & address
            db 10h
            db 0Fh
            dw 0400h
            ; Link to next file
            dw File10End
incbin 'dist/prg/screen_nochar.prg'
File10End:

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

            ; File type, load bank & address
            db 11h
            db 0Fh
            dw 0400h
            ; Link to next file
            dw File11End
incbin 'dist/prg/screen_char.prg'
File11End:

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

            ; End of binary payload
            db 0FFh
PayloadEnd:

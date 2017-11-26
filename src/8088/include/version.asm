
%define VERSION_STRING		"0.61"
VERSION_NUMBER		equ		61

Version_Banner:
			db "IBM PC Compatibility layer v", VERSION_STRING, " "
%ifdef ROM
			db "ROM "
%endif
			db "installed.", 10, 13, 0, '$'

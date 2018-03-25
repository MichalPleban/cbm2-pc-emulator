
%define VERSION_STRING		"0.65"
VERSION_NUMBER		equ		65


Version_Banner:
			db "PC Compatibility layer v", VERSION_STRING, " "
%ifdef ROM
			db "ROM "
%endif
			db "(C) 2017-2018 Micha", 9Ch, " Pleban", 10, 13, 0, '$'

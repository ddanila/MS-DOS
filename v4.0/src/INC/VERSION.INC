ifndef VERSION_INC_INCLUDED
VERSION_INC_INCLUDED EQU 1
; Some modules really want TRUE to be 0FFH.  Best to let them have their way.
ifndef TRUE
	TRUE	   EQU	   0FFFFh
endif
ifndef TRUEBYTE
	TRUEBYTE   EQU     0FFh
endif
ifndef FALSE
	FALSE	   EQU	   0
endif

;
; Use the following switches to control cmacros.inc
;
?PLM       =       0
?WIN       =       0

memS       EQU     1			; Small model
;
; Use the switches below to produce the standard Microsoft version or the IBM
; version of the operating system
;
; The below chart will indicate how to set the switches to build the various
; versions
;
;                     IBMVER          IBMCOPYRIGHT
; --------------------------------------------------------
;  IBM Version   |     TRUE              TRUE
; --------------------------------------------------------
;  MS Version    |     FALSE             FALSE
; --------------------------------------------------------
;  Clone Version |     TRUE              FALSE
;
ifndef IBMVER
IBMVER     EQU     TRUE
endif
ifndef IBMCOPYRIGHT
IBMCOPYRIGHT EQU   FALSE
endif

ifndef BUFFERFLAG
BUFFERFLAG	EQU	NOT IBMCOPYRIGHT
endif

ifndef	MSVER	
MSVER      EQU     NOT IBMVER
endif
ifndef IBM
IBM	   EQU	   IBMVER
endif
;
;
;
;
;***************************************************************************
;*          The following switches are for DBCS or SBCS support            *
;*                                                                         *
;*                     Set INTERNAT EQU TRUE FOR DBCS                      *
;*                     Set INTERNAT EQU FALSE FOR SBCS                     *
;*                                                                         *
;***************************************************************************
;
ifndef IBMJAPVER
IBMJAPVER  EQU	   FALSE		;If TRUE set KANJI true also
endif

;
; Switch INTERNAT for DBCS support
;
ifndef INTERNAT
INTERNAT   EQU	   FALSE
endif
;
	IF INTERNAT
ifndef KANJI
KANJI	   EQU	   TRUE
endif
ifndef IBMJAPAN
IBMJAPAN   EQU	   TRUE
endif
	ELSE
ifndef KANJI
KANJI	   EQU	   FALSE
endif
ifndef IBMJAPAN
IBMJAPAN   EQU	   FALSE
endif
	ENDIF

ifndef altvect				; avoid jerking off vector.inc
ALTVECT    EQU	   FALSE		;Switch to build ALTVECT version
endif

;
; Country code switches
; The default contry code is assumed as USA.
;
	IF INTERNAT
 KOREA	   EQU	   TRUE
 JAPAN	   EQU	   FALSE
	ELSE
 KOREA	   EQU	   FALSE
 JAPAN	   EQU	   FALSE
	ENDIF
;

endif ; VERSION_INC_INCLUDED

list		p=PIC18F45K22
#include	"p18f45k22.inc"
 ;--- Configuration bits ---
    CONFIG  FOSC = INTIO67        ; Oscillator Selection bits (Internal oscillator block, port function on RA6 and RA7)
    CONFIG  WDTEN = OFF           ; Watchdog Timer Enable bit (WDT is controlled by SWDTEN bit of the WDTCON register
    CONFIG  LVP = ON              ; ***Single-Supply ICSP Enable bit (Single-Supply ICSP enabled if MCLRE is also 1)
    
    cblock
	OPENSWITCH ; voltage value for when capacitor switch not pressed
	CTMUVOLTAGE 
	CAPSWITCHPRESSED 
    endc
    
    org 00h ; Reset Vector
	GOTO STARTUP	
	
STARTUP
	;Oscillator set at 4 MHz
	BSF 	OSCCON,IRCF0
	BCF	OSCCON,IRCF1
	BSF	OSCCON,IRCF2
	MOVLB ; BSR TODO
	MOVLW	0xTODO ;;;;;;;;;;;;;;;;;; TODO
	MOVWF	OPENSWITCH ; Set what the voltage value for the open switch is
	
;---------- CTMU Setup -------------
	MOVLW	B'00000000'
	MOVWF	CTMUCONH
	MOVLW	B'10010000' ; Edge 2 positive edge response, EECP2 special event trigger, positive edge response,
	MOVWF	CTMUCONL
	MOVLW	B'00000001'
	MOVWF	CTMUICON ; Current source is nominal base current level (0.55uA)

;---------- ADC for CTMU setup ----------
	MOVLW	B'10111110' ; Right Justified, 20TAD, FOSC/64
	MOVWF	ADCON2
	MOVLW	B'10000000' ; Trigger from CTMU, AVdd and AVss reference voltages
	MOVWF	ADCON1
	MOVLW	B'00001000'
	MOVWF	ADCON0
	; PORT for ADC
	BSF TRISA,2 ; Channel 2 is input
	BSF ANSELA,2 ; is ADC input
	BSF ADCON0,ADON ; enable ADC
	
;--------- CMTU operation -------------
CAPDETECT
	BSF CTMUCONH,CTMUEN ; enable CTMU
	BCF CTMUCONL,EDG1SAT ; edge status bits = zero
	BCF CTMUCONL,EDG2SAT
	BSF CTMUCONH,IDISSEN ; drain charge on circuit
	;delay 125us
	BCF CTMUCONL,IDISSEN ; End draining of circuit
	BSF CTMUCONL,EDG1SAT ; Begin charging of cicuit using CTMU current source (0.55uA)
	;delay 125us
	BCF CTMUCONL,EDG1SAT ; Finish circuit charging
	BCF PIR1,ADIF; Make sure ADC not currently converting
	BSF ADCON0,GO ; start ADC conversion
	BTFSC 	ADCON0,GO ; finished yet?
	BRA 	$-2 ; not finished
	; conversion now finished
	MOVFF	ADRESL,CTMUVOLTAGE
	MOVF	OPENSWITCH,0 ; W = open switch value
	CPFSLT	CTMUVOLTAGE ; skip next line if CTMUVOLTAGE < open switch voltage
	GOTO	NOTPRESSED
	BSF CAPSWITCHPRESSED,0    ; smaller voltage when pressed
	GOTO ENDCAP
NOTPRESSED
	BCF CAPSWITCHPRESSED,0    ; larger voltage when not pressed
ENDCAP	GOTO	CAPDETECT
    end
    
    
    ; TODO CHECK BANK SWITCHING
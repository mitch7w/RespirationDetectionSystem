; Mitchell Williams u18013555
; EMK Home Practical Am I Breathing?

    list	 p=PIC18F45K22
    #include	"p18f45k22.inc"

;--- Configuration bits ---
    CONFIG  FOSC = INTIO67        ; Oscillator Selection bits (Internal oscillator block, port function on RA6 and RA7)
    CONFIG  WDTEN = OFF           ; Watchdog Timer Enable bit (WDT is controlled by SWDTEN bit of the WDTCON register
    CONFIG  LVP = ON              ; ***Single-Supply ICSP Enable bit (Single-Supply ICSP enabled if MCLRE is also 1)
    
    cblock
	ADCRESULT
	hello
    endc
    ;org 08h ISR Vector
	;GOTO ADCISR
    org 00h ; Reset Vector
    
     ;------- Setup PORTD for ADC LED output ----------
    
	    CLRF PORTA
	    CLRF TRISA
	    MOVLW   B'00000000'
	    MOVWF PORTA ; All LEDs on PORTD off
    
    ;---- Setup ADC ----
	    MOVLB 0xF ; ADC bank
	    clrf ADRESH
	    clrf ADCRESULT
	    MOVLW B'00101111'; ADC settings: left justified,internal oscillator and 12TAD
	    MOVWF ADCON2
	    MOVLW B'00000000'; ADC settings: ADC refs are Vdd and Vss
	    MOVWF ADCON1
	    MOVLW B'00000000' ; ADC settings: Use Port RB0
	    MOVWF ADCON0
	    BSF ANSELA,0 ; RB0 used for ADC (not IO)
	    BSF TRISA,0 ; RB0 is an input
	    BSF ADCON0,ADON ; ADC's ANO enabled
	    MOVLB 0x0 ; Back to main bank
	    
	    CLRF ADCRESULT
	    
POLL    BSF ADCON0, GO ; Start ADC conversion
	    BTFSC ADCON0,GO ; If conversion done skip the next line
	    BRA $-2 ; Loop until conversion is donne
	    
	    ; Conversion now done
	    
	    MOVLW 0xFF
	    MOVWF PORTA
	    MOVF ADRESH,W ; Read upper eight bytes of ADC (8bit conversion)
	    MOVWF ADCRESULT ;
	    MOVLW 0x0
	    MOVWF PORTA
	    ; Now read ADCRESULT to see what it says
	    CLRF ADCRESULT
	    GOTO POLL ;
	    end
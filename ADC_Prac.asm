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
    endc
    
    ;---- Setup ADC ----
	    MOVLB OxF ; ADC bank
	    clrf ADRESH
	    clrf ADCRESULT
	    MOVLW ; ADC setting
	    MOVWF ADCON2
	    MOVLW ; ADC settings
	    MOVWF ADCON1
	    BSF ANSELA,0 ; RA0 used for ADC (not IO)
	    BSF TRISA,0 ; RA0 is an input
	    BSF ADCON0, ADON ; ADC's ANO enabled
	    MOVLB 0x0 ; Back to main bank

    ;------- Setup PORTD for ADC output ----------
	    CLRF PORTD
	    CLRF TRISD
    
    ;---- Conversion polling--------- TODO : CHANGE THIS TO AN INTERRUPT
    POLL    BSF ADCON0, GO ; Start ADC conversion
	    BTFSC ADCON0,GO ; If conversion done skip the next line
	    BRA $-2 ; Loop until conversion is donne
	    
	    ; Conversion now done
	    
	    MOVF ADRESH,W ; Read upper eight bytes of ADC (8bit conversion)
	    MOVWF ADCRESULT ;
   
	    ; ------ Set up LED output if value is in certain range -------
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
	LOWTHRESHOLD
	HIGHTHRESHOLD
	REACHEDHIGH
	BREATHPM
	NUMBREATHSCOUNTED
	AVGCALC
    endc
    ;org 08h ISR Vector
	;GOTO ADCISR
    org 00h ; Reset Vector
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
	    
    ;------Initialize variables-------------
    
	    CLRF REACHEDHIGH ; REACHEDHIGH = 0
	    CLRF BREATHPM ; BREATHPM = 0
	    CLRF NUMBREATHSCOUNTED ; numBreaths = 0
	    CLRF AVGCALC ; avgCalc = 0
	    
    ;------- Setup PORTD for ADC LED output ----------
	    CLRF PORTD
	    CLRF TRISD
	    MOVLW   b'00000000'
	    MOVWF PORTD ; All LEDs on PORTD off
	    
;------- Setup Timer2 for counting respiration rate ----------
	    MOVLW b'00000001' ; TODO change this to correct postscalar values and whatnot
	    MOVWF T2CON
	    MOVLW d'200'
	    MOVWF PR2 ; preloading period values or something TODO read datasheet to understand this
	    
	    	    
    
    ;---- Conversion polling--------- TODO : CHANGE THIS TO AN INTERRUPT
    POLL    BSF ADCON0, GO ; Start ADC conversion
	    BTFSC ADCON0,GO ; If conversion done skip the next line
	    BRA $-2 ; Loop until conversion is donne
	    
	    ; Conversion now done
	    
	    MOVF ADRESH,W ; Read upper eight bytes of ADC (8bit conversion)
	    MOVWF ADCRESULT ;
	    CALL ADCISR ; proper interrupt not set up yet
	    GOTO POLL ;
   
	    ; ------ Turn on LED if value is high - exhaling-------
	    ; ------ Turn off LED if value is low - inhaling-------

ADCISR
	    MOVF LOWTHRESHOLD,W ; put low threshold in W for comparison
EvaluateL   CPSLT ADCRESULT; if ADCRESULT lower than lowThreshold call LOW subroutine
	    BRA EvaluateH ; Not lower than low threshold
	    CALL SRLOW ; Calls LOW subroutine
	    BRA ADCEND ; Makes surehigh isn't evaluated
EvaluateH   MOVF HIGHTHRESHOLD,W ; Put high threshold in W for comparison
	    CPSGT ADCRESULT ; if ADCRESULT higher than high threshold call high subroutine
	    BRA ADCEND; not higher than high threshold - not low or high
	    CALL SRHIGH
ADCEND	    RETFIE
	
	    

SRLOW	    MOVLW b'11111111'
	    CPFSEQ REACHEDHIGH,W ; skip next line if reachedHigh = true
	    BRA TIMERCHECK ; reachedHigh not = true, go to timerCheck
	    ; reachedHigh is = true
	    BCF TMR2CON,TMR2ON ; switch off timer
	    MOVFW TMR2
	    ; stop timer
	    MOVFW TMR2; write breath period to W
	    ADDWF AVGCALC ; AVGCALC gets new value of timer added each time
	    MOVLW 0x01
	    ADDLW NUMBREATHSCOUNTED; WREG++
	    MOVWF NUMBREATHSCOUNTED ; numBreathsCounted++
	    MOVLW 0x08
	    CPFSLT NUMBREATHSCOUNTED ; if numBreathsCounted < 8 skip next line
	    CALL SRAVERAGEBREATHS; numBreathsCounted = 8
	    BRA LOWRETURN
TIMERCHECK  
	    MOVLW b'0'
	    CPFSEQ TMR2ON,W ; Skip next line if timer not started TODO Check notation
	    BRA LOWRETURN ; timer has started
	    CLRF TMR2 ; if timer not started start it
	    BSF T2CON,TMR2ON    
LOWRETURN   RETURN
	    
SRHIGH	    MOVLW b'0'
	    CPFSEQ TMR2ON,W ; Skip next line if timer not started TODO Check notation
	    BSF REACHEDHIGH ; reachedHigh = true	    
HIGHRETURN  RETURN
	    
	    
SRAVERAGEBREATHS    ; Average last 8 breaths to get respiration rate
	    ; AVGCALC contains sum of all breath periods
	    ; divide avgcalc by 8 to get avg period
	    ; divide 1 by result to get breath per second
	    MOVLW 0x3c ; 60
	    MULLW AVGCALC; multiply by 60 to get breath pm
	    ; multiplication result stored in PRODH and PRODL
	    MOVFW PRODL ; assuming product never uses prodH
	    MOVWF BREATHPM; write result to BREATHPM
	    CALL PICLEDS
	    BCF NUMBREATHSCOUNTED ; start counting numBreaths again
	    BCF REACHEDHIGH ; reachedHigh = false
	    BCF AVGCALC ; the average register must be cleared
	    RETURN 
	    
; -------- Subroutine to SET PIC LEDs ----------
PICLEDS
	; Check value of BREATHPM and set various PIC LEDs accordingly		
    Less12
	    
	    MOVLW 0xC
	    CPFSLT BREATHPM ; skip next line if BREATHPM < 12
	    GOTO Less16 ; BREATHPM > 12
	    MOVLW   b'00000000' ; BREATHPM <12
	    MOVWF PORTD ; All LEDs on PORTD off
    Less16
	    MOVLW 0x10
	    CPFSLT BREATHPM ; skip next line if BREATHPM < 16
	    GOTO Less20 ; BREATHPM > 16
	    MOVLW   b'00000001' ; BREATHPM is between 12 and 16
	    MOVWF PORTD ; 1 LED on PORTD on
Less20
	    MOVLW 0x14
	    CPFSLT BREATHPM ; skip next line if BREATHPM < 20
	    GOTO Less30 ; BREATHPM > 20
	    MOVLW   b'00000011' ; BREATHPM is between 16 and 20
	    MOVWF PORTD ; 2 LEDs on PORTD on
Less30
	    MOVLW 0x1E
	    CPFSLT BREATHPM ; skip next line if BREATHPM < 30
	    GOTO Greater30 ; BREATHPM > 30
	    MOVLW   b'00000111' ; BREATHPM is between 20 and 30
	    MOVWF PORTD ; 3 LEDs on PORTD on
Greater30
	    MOVLW   b'00001111' ; BREATHPM is between 16 and 20
	    MOVWF PORTD ; 4 LEDs on PORTD on
	    RETURN ; PICLEDS Subroutine returns
	    
end